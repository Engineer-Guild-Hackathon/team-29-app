from pathlib import Path
import re
text = Path('post_problem_form.dart').read_text(encoding='utf-8')
pattern = re.compile(r"\s+final titleText =.*?AppBreadcrumbs\((?:[^()]+|\([^()]*\))*\),", re.DOTALL)
match = pattern.search(text)
print('found' if match else 'not found')
if match:
    print(match.group(0))
