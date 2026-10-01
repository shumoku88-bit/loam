use serde::Serialize;
use std::{
    env,
    path::{Path, PathBuf},
    process::Command,
};

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ActualEffect {
    locus: String,
    measure: String,
    quanta: String,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ActualRecord {
    id: String,
    date: String,
    description: String,
    effects: Vec<ActualEffect>,
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

fn parse_actual1(stdout: &str, requested_month: &str) -> Result<ActualMonth, String> {
    let mut records: Vec<ActualRecord> = Vec::new();
    let mut schema_ok = false;
    let mut month_ok = false;
    let mut complete = false;

    for line in stdout.lines() {
        if line.is_empty() {
            continue;
        }
        let fields: Vec<&str> = line.split('\t').collect();
        if fields.first().copied() != Some("ACTUAL1") {
            return Err("loam-gui: unexpected Actual transport prefix".into());
        }
        match fields.get(1).copied() {
            Some("meta") if fields.len() == 4 => match fields[2] {
                "schema" => schema_ok = fields[3] == "1",
                "month" => month_ok = fields[3] == requested_month,
                "status" => complete = fields[3] == "complete",
                _ => {}
            },
            Some("record") if fields.len() == 5 => {
                records.push(ActualRecord {
                    id: fields[2].to_string(),
                    date: fields[3].to_string(),
                    description: fields[4].to_string(),
                    effects: Vec::new(),
                });
            }
            Some("effect") if fields.len() == 6 => {
                let Some(record) = records.iter_mut().find(|record| record.id == fields[2]) else {
                    return Err("loam-gui: effect arrived before its Actual record".into());
                };
                record.effects.push(ActualEffect {
                    locus: fields[3].to_string(),
                    measure: fields[4].to_string(),
                    quanta: fields[5].to_string(),
                });
            }
            Some("meta") => {}
            _ => return Err(format!("loam-gui: malformed Actual transport line: {line}")),
        }
    }

    if !schema_ok {
        return Err("loam-gui: unsupported or missing ACTUAL1 schema".into());
    }
    if !month_ok {
        return Err("loam-gui: ACTUAL1 month did not match the request".into());
    }
    if !complete {
        return Err("loam-gui: incomplete ACTUAL1 stream".into());
    }

    Ok(ActualMonth {
        month: requested_month.to_string(),
        records,
    })
}

#[tauri::command]
fn load_actual(month: String, data_dir: Option<String>) -> Result<ActualMonth, String> {
    if month.len() != 7
        || !month
            .chars()
            .enumerate()
            .all(|(i, c)| if i == 4 { c == '-' } else { c.is_ascii_digit() })
    {
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
        .args(["explain", "actual", "--machine", "--month", &month]);

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
    parse_actual1(&stdout, &month)
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
    use super::parse_actual1;

    #[test]
    fn parses_complete_actual_transport() {
        let source = concat!(
            "ACTUAL1\tmeta\tschema\t1\n",
            "ACTUAL1\tmeta\tmonth\t2026-10\n",
            "ACTUAL1\trecord\te1\t2026-10-01\tgroceries\n",
            "ACTUAL1\teffect\te1\tpaypay\tjpy\t-680\n",
            "ACTUAL1\teffect\te1\tfood\tjpy\t680\n",
            "ACTUAL1\tmeta\tstatus\tcomplete\n",
        );
        let parsed = parse_actual1(source, "2026-10").expect("valid ACTUAL1");
        assert_eq!(parsed.records.len(), 1);
        assert_eq!(parsed.records[0].effects.len(), 2);
    }

    #[test]
    fn rejects_truncated_actual_transport() {
        let source = concat!(
            "ACTUAL1\tmeta\tschema\t1\n",
            "ACTUAL1\tmeta\tmonth\t2026-10\n",
        );
        assert!(parse_actual1(source, "2026-10").is_err());
    }
}
