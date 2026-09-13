from pathlib import Path

source_path = Path('.github/scripts/apply_accounting_tui_patch.py')
source = source_path.read_text()
old = '''replace_once(
    reports,
    "      transactionsSnapshot := none\\n      transactionsIndex := 0\\n",
    "      transactionsSnapshot := none\\n      accountingSnapshot := none\\n      transactionsIndex := 0\\n",
)

# The same pair occurs in clearResults after withError; replace the remaining one.
replace_once(
    reports,
    "      transactionsSnapshot := none\\n      transactionsIndex := 0\\n",
    "      transactionsSnapshot := none\\n      accountingSnapshot := none\\n      transactionsIndex := 0\\n",
)
'''
new = '''p = Path(reports)
text = p.read_text()
old_pair = "      transactionsSnapshot := none\\n      transactionsIndex := 0\\n"
new_pair = "      transactionsSnapshot := none\\n      accountingSnapshot := none\\n      transactionsIndex := 0\\n"
count = text.count(old_pair)
if count != 2:
    raise SystemExit(f"{reports}: expected two snapshot-clear matches, found {count}")
p.write_text(text.replace(old_pair, new_pair))
'''
count = source.count(old)
if count != 1:
    raise SystemExit(f'patch-driver rewrite expected one match, found {count}')
source = source.replace(old, new, 1)
exec(compile(source, str(source_path), 'exec'))
