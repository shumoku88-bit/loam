use serde::Serialize;
use std::{
    collections::HashSet,
    env,
    path::{Path, PathBuf},
    process::Command,
};

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ActualEffect {
    locus: String,
    measure: String,
    // Exact quanta are text, never a floating-point JSON number.
    quanta: String,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct HistoricalRecord {
    id: String,
    replacement: String,
    // Empty means unknown; it must not inherit the replacement's date.
    date: String,
    description: String,
    effects: Vec<ActualEffect>,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ActualRecord {
    id: String,
    date: String,
    description: String,
    effects: Vec<ActualEffect>,
    history: Vec<HistoricalRecord>,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ActualMonth {
    month: String,
    records: Vec<ActualRecord>,
}

fn repository_root() -> Result<PathBuf, String> {
    if let Ok(path) = env::var("LOAM_GUI_REPO_ROOT") {
        if !path.is_empty() {
            return Ok(PathBuf::from(path));
        }
    }

    Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .and_then(Path::parent)
        .map(Path::to_path_buf)
        .ok_or_else(|| "loam-gui: could not resolve repository root".to_string())
}

fn loam_binary(root: &Path) -> PathBuf {
    env::var("LOAM_GUI_LOAM_BIN")
        .map(PathBuf::from)
        .unwrap_or_else(|_| root.join(".lake").join("build").join("bin").join("loam"))
}

fn valid_month(month: &str) -> bool {
    if month.len() != 7
        || !month.bytes().enumerate().all(|(i, c)| {
            if i == 4 {
                c == b'-'
            } else {
                c.is_ascii_digit()
            }
        })
    {
        return false;
    }
    matches!(month[..4].parse::<u32>(), Ok(1..=9999))
        && matches!(month[5..].parse::<u32>(), Ok(1..=12))
}

fn valid_date(date: &str) -> bool {
    if date.len() != 10
        || !date.bytes().enumerate().all(|(i, c)| {
            if i == 4 || i == 7 {
                c == b'-'
            } else {
                c.is_ascii_digit()
            }
        })
        || !valid_month(&date[..7])
    {
        return false;
    }
    let year = date[..4].parse::<u32>().unwrap();
    let month = date[5..7].parse::<u32>().unwrap();
    let days = match month {
        2 if year % 400 == 0 || (year % 4 == 0 && year % 100 != 0) => 29,
        2 => 28,
        4 | 6 | 9 | 11 => 30,
        _ => 31,
    };
    matches!(date[8..].parse::<u32>(), Ok(day) if (1..=days).contains(&day))
}

fn valid_token(token: &str) -> bool {
    // Match Persistence.TokenSyntax: opaque tokens may contain spaces.
    !token.is_empty() && !token.contains(['\t', '\n', '\r'])
}

fn exact_integer(text: &str) -> bool {
    let digits = text.strip_prefix('-').unwrap_or(text);
    if digits == "0" {
        return text == "0";
    }
    !digits.is_empty() && !digits.starts_with('0') && digits.bytes().all(|c| c.is_ascii_digit())
}

fn effect(locus: &str, measure: &str, quanta: &str) -> Result<ActualEffect, String> {
    if !valid_token(locus) || !valid_token(measure) || !exact_integer(quanta) {
        return Err("loam-gui: malformed exact Effect transport".into());
    }
    Ok(ActualEffect {
        locus: locus.into(),
        measure: measure.into(),
        quanta: quanta.into(),
    })
}

// This validates presentation framing/ownership, not accounting or correction admission.
// Those belong to ActualReview over the admitted ActualAuthority image in LOAM.
fn parse_actual1(stdout: &str, requested_month: &str) -> Result<ActualMonth, String> {
    if !valid_month(requested_month) {
        return Err("loam-gui: month must be YYYY-MM".into());
    }
    let mut records: Vec<ActualRecord> = Vec::new();
    let mut identities = HashSet::new();
    let mut schema_ok = false;
    let mut month_ok = false;
    let mut complete = false;

    for line in stdout.lines().filter(|line| !line.is_empty()) {
        if complete {
            return Err("loam-gui: data followed ACTUAL1 completion".into());
        }
        let fields: Vec<&str> = line.split('\t').collect();
        match fields.as_slice() {
            ["ACTUAL1", "meta", "schema", "2"] if !schema_ok => schema_ok = true,
            ["ACTUAL1", "meta", "implementation", "loam"]
            | ["ACTUAL1", "meta", "question", "actual-month"]
                if schema_ok && !month_ok => {}
            ["ACTUAL1", "meta", "month", month]
                if schema_ok && !month_ok && *month == requested_month =>
            {
                month_ok = true;
            }
            ["ACTUAL1", "meta", "status", "complete"] if schema_ok && month_ok => {
                complete = true;
            }
            ["ACTUAL1", "record", id, date, description] if schema_ok && month_ok => {
                if !valid_token(id)
                    || !identities.insert((*id).to_string())
                    || !valid_date(date)
                    || &date[..7] != requested_month
                {
                    return Err("loam-gui: invalid or duplicate current Actual record".into());
                }
                records.push(ActualRecord {
                    id: (*id).into(),
                    date: (*date).into(),
                    description: (*description).into(),
                    effects: Vec::new(),
                    history: Vec::new(),
                });
            }
            ["ACTUAL1", "effect", owner, locus, measure, quanta] => {
                let record = records
                    .last_mut()
                    .filter(|record| record.id == *owner && record.history.is_empty())
                    .ok_or("loam-gui: Effect does not belong to the current record block")?;
                record.effects.push(effect(locus, measure, quanta)?);
            }
            ["ACTUAL1", "history", owner, id, replacement, date, description] => {
                let record = records
                    .last_mut()
                    .filter(|record| record.id == *owner)
                    .ok_or("loam-gui: history does not belong to the current record block")?;
                if !valid_token(id)
                    || !valid_token(replacement)
                    || !identities.insert((*id).to_string())
                    || (!date.is_empty() && !valid_date(date))
                {
                    return Err("loam-gui: invalid or duplicate historical Actual record".into());
                }
                record.history.push(HistoricalRecord {
                    id: (*id).into(),
                    replacement: (*replacement).into(),
                    date: (*date).into(),
                    description: (*description).into(),
                    effects: Vec::new(),
                });
            }
            ["ACTUAL1", "history-effect", owner, id, locus, measure, quanta] => {
                let previous = records
                    .last_mut()
                    .filter(|record| record.id == *owner)
                    .and_then(|record| record.history.last_mut())
                    .filter(|previous| previous.id == *id)
                    .ok_or("loam-gui: historical Effect has no matching history block")?;
                previous.effects.push(effect(locus, measure, quanta)?);
            }
            _ => return Err("loam-gui: unsupported or malformed ACTUAL1 schema 2 stream".into()),
        }
    }

    if !schema_ok || !month_ok || !complete {
        return Err("loam-gui: incomplete ACTUAL1 schema 2 stream".into());
    }
    for record in &records {
        for (index, previous) in record.history.iter().enumerate() {
            let next = record
                .history
                .get(index + 1)
                .map_or(&record.id, |next| &next.id);
            if &previous.replacement != next {
                return Err(
                    "loam-gui: history is not a closed ordered path to its current record".into(),
                );
            }
        }
    }

    Ok(ActualMonth {
        month: requested_month.to_string(),
        records,
    })
}

fn read_actual(month: &str, data_dir: Option<String>) -> Result<ActualMonth, String> {
    if !valid_month(month) {
        return Err("loam-gui: month must be YYYY-MM".into());
    }
    let root = repository_root()?;
    let binary = loam_binary(&root);
    if !binary.is_file() {
        return Err(format!(
            "loam-gui: LOAM binary not found at {}. Run lake build loam first.",
            binary.display()
        ));
    }
    let mut command = Command::new(&binary);
    command
        .current_dir(&root)
        .args(["explain", "actual", "--machine", "--month", month]);
    if let Some(path) = data_dir.filter(|path| !path.trim().is_empty()) {
        command.arg(path);
    }
    let output = command
        .output()
        .map_err(|error| format!("loam-gui: failed to start LOAM: {error}"))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
        return Err(if stderr.is_empty() {
            format!("loam-gui: LOAM exited with {}", output.status)
        } else {
            stderr
        });
    }
    let stdout = String::from_utf8(output.stdout)
        .map_err(|_| "loam-gui: LOAM emitted non-UTF-8 Actual output".to_string())?;
    parse_actual1(&stdout, month)
}

#[tauri::command]
async fn load_actual(month: String, data_dir: Option<String>) -> Result<ActualMonth, String> {
    // Keep process I/O off the webview event loop, including when users change months quickly.
    tauri::async_runtime::spawn_blocking(move || read_actual(&month, data_dir))
        .await
        .map_err(|error| format!("loam-gui: Actual reader failed: {error}"))?
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![load_actual])
        .run(tauri::generate_context!())
        .expect("error while running LOAM GUI");
}

#[cfg(test)]
mod tests {
    use super::{parse_actual1, valid_date, valid_month};

    fn stream(body: &str) -> String {
        format!(
            "ACTUAL1\tmeta\tschema\t2\nACTUAL1\tmeta\tmonth\t2026-10\n{body}ACTUAL1\tmeta\tstatus\tcomplete\n"
        )
    }

    #[test]
    fn parses_exact_current_and_cross_month_unknown_date_ancestry() {
        let source = stream(concat!(
            "ACTUAL1\trecord\tcurrent\t2026-10-01\tgroceries\n",
            "ACTUAL1\teffect\tcurrent\tpaypay\tjpy\t-900719925474099312345\n",
            "ACTUAL1\teffect\tcurrent\tfood\tjpy\t900719925474099312345\n",
            "ACTUAL1\thistory\tcurrent\told\tmiddle\t2026-09-30\tbefore\n",
            "ACTUAL1\thistory-effect\tcurrent\told\tcash\tjpy\t-100\n",
            "ACTUAL1\thistory\tcurrent\tmiddle\tcurrent\t\tintermediate\n",
        ));
        let parsed = parse_actual1(&source, "2026-10").unwrap();
        assert_eq!(parsed.records.len(), 1);
        assert_eq!(parsed.records[0].effects[1].quanta, "900719925474099312345");
        assert_eq!(parsed.records[0].history[0].id, "old");
        assert_eq!(parsed.records[0].history[0].effects[0].quanta, "-100");
        assert_eq!(parsed.records[0].history[1].date, "");
    }

    #[test]
    fn accepts_empty_month_without_manufacturing_records() {
        assert!(parse_actual1(&stream(""), "2026-10")
            .unwrap()
            .records
            .is_empty());
    }

    #[test]
    fn refuses_bad_framing_and_months() {
        for source in [
            "ACTUAL1\tmeta\tschema\t2\nACTUAL1\tmeta\tmonth\t2026-10\n".to_string(),
            stream("").replace("schema\t2", "schema\t1"),
            stream("").replace("month\t2026-10", "month\t2026-09"),
            stream("") + "ACTUAL1\trecord\te1\t2026-10-01\tlate\n",
            stream("ACTUAL1\tmeta\tstatus\tcomplete\n"),
            stream("ACTUAL1\tmeta\tmonth\t2026-10\n"),
            stream("ACTUAL1\tmeta\tunknown\n"),
            stream("ACTUAL1\trecord\te1\t2026-09-01\twrong month\n"),
        ] {
            assert!(parse_actual1(&source, "2026-10").is_err(), "{source}");
        }
        for month in ["2026-00", "2026-13", "0000-10", "2026-1", "２０２６-１０"] {
            assert!(!valid_month(month));
        }
        assert!(valid_date("2024-02-29"));
        assert!(!valid_date("2026-02-29"));
    }

    #[test]
    fn refuses_unowned_duplicate_open_or_cyclic_history() {
        for body in [
            "ACTUAL1\teffect\te1\tcash\tjpy\t100\n",
            "ACTUAL1\trecord\te1\t2026-10-01\tx\nACTUAL1\trecord\te1\t2026-10-02\ty\n",
            "ACTUAL1\trecord\te1\t2026-10-01\tx\nACTUAL1\thistory\tother\told\te1\t\tx\n",
            "ACTUAL1\trecord\te1\t2026-10-01\tx\nACTUAL1\thistory\te1\told\tmissing\t\tx\n",
            "ACTUAL1\trecord\te1\t2026-10-01\tx\nACTUAL1\thistory\te1\te1\te1\t\tx\n",
            "ACTUAL1\trecord\te1\t2026-10-01\tx\nACTUAL1\thistory\te1\told\told\t\tx\n",
            "ACTUAL1\trecord\te1\t2026-10-01\tx\nACTUAL1\thistory-effect\te1\told\tcash\tjpy\t100\n",
            "ACTUAL1\trecord\te1\t2026-10-01\tx\nACTUAL1\thistory\te1\told\te1\t2026-02-29\tx\n",
            "ACTUAL1\trecord\te1\t2026-10-01\tx\nACTUAL1\thistory\te1\told\te1\t\tx\nACTUAL1\thistory\te1\told\te1\t\tx\n",
        ] {
            assert!(parse_actual1(&stream(body), "2026-10").is_err(), "{body}");
        }
    }

    #[test]
    fn preserves_opaque_tokens_with_spaces() {
        let body = "ACTUAL1\trecord\tevent one\t2026-10-01\tx\nACTUAL1\teffect\tevent one\tcash wallet\tjpy\t100\n";
        let parsed = parse_actual1(&stream(body), "2026-10").unwrap();
        assert_eq!(parsed.records[0].id, "event one");
        assert_eq!(parsed.records[0].effects[0].locus, "cash wallet");
    }

    #[test]
    fn refuses_inexact_or_malformed_effects() {
        for quanta in ["", "1.5", "1e3", "+1", "--1", "-0", "01", "NaN"] {
            let body = format!(
                "ACTUAL1\trecord\te1\t2026-10-01\tx\nACTUAL1\teffect\te1\tcash\tjpy\t{quanta}\n"
            );
            assert!(parse_actual1(&stream(&body), "2026-10").is_err());
        }
    }
}
