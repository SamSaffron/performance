import openai
import requests
from bs4 import BeautifulSoup

openai.api_key = "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"

url = "https://meta.discourse.org/t/summarising-topics-with-an-llm-gpt-bert/254951.json"
url = "https://meta.discourse.org/t/are-the-custom-fields-searchable-in-the-user-directory/246331.json"
url = "https://meta.discourse.org/t/ios-16-web-push-notifications-in-2023/229240.json"

response = requests.get(url)
data = response.json()

messages = []
messages.append("Title: " + data["title"])
for post in data['post_stream']['posts']:
    soup = BeautifulSoup(post['cooked'], 'html.parser')
    messages.append("Post #" + str(post["post_number"]) + " by " + post["username"])
    messages.append(soup.get_text())

text_blob = "\n".join(messages)

print(text_blob)

max_chunk_len = 4000  # Maximum length of each chunk

chunks = [text_blob[i:i+max_chunk_len] for i in range(0, len(text_blob), max_chunk_len)]

summaries = []
for chunk in chunks:
    print("processing chunk")
    response = openai.Completion.create(
        engine="text-davinci-003",
        prompt="prompt (discourse topic):\n" + chunk + "\nsummary:",
        temperature=0.2,
        max_tokens=200,
        top_p=0.9,
        frequency_penalty=0,
        presence_penalty=0
    )
    summary = response.choices[0].text.strip()
    print("\nSUMMARY")
    print(summary)
    print("\nSUMMARY")
    summaries.append(summary)
    exit()

exit()
final_summary = openai.Completion.create(
    engine="text-davinci-003",
    prompt="\n".join(summaries),
    temperature=0.7,
    max_tokens=200,
    top_p=1,
    frequency_penalty=0,
    presence_penalty=0
)

print("Original text:")
print(text_blob)
print("\nSummaries:")
for summary in summaries:
    print(summary)
print("\nFinal summary:")
print(final_summary.choices[0].text.strip())

