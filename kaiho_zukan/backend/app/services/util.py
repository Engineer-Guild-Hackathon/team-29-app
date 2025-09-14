import re

def extract_json_block(text: str) -> str:
    """
    ```json ... ``` 柵や前後の説明文を除き、JSON本体({ ... })だけを取り出す。
    見つからなければ元の文字列を返す。
    """
    if not text:
        return text
    m = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", text, re.S | re.I)
    if m:
        return m.group(1)
    i, j = text.find("{"), text.rfind("}")
    if i != -1 and j != -1 and i < j:
        return text[i:j+1]
    return text
