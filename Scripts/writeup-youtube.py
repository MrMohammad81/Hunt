import requests
import json
import time
from tinydb import TinyDB, Query
from apiclient.discovery import build
import discord
from discord.ext import commands
from discord import Embed

# Your Discord bot token
DISCORD_BOT_TOKEN = "Token"

# Your Discord channel ID
DISCORD_CHANNEL_ID = "ID"

# Your YouTube API key
YOUTUBE_API_KEY = "KEY"

intents = discord.Intents.default()  # Create an instance of Intents
intents.all()  # Enable all available intents

# Create a Discord bot instance
bot = commands.Bot(command_prefix='!', intents=intents)
# TinyDB setup
db = TinyDB('db.json')
Posts = Query()
medium_articles = db.table('medium_articles')
youtube_videos = db.table('youtube_videos')

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
    'Accept': '*/*',
    'Accept-Encoding': 'gzip,deflate',
    'Accept-language': 'en-US,en;q=0.5',
    'content-type': 'application/json',
    'origin': 'https://medium.com',
    'connection': 'close'
}

YoutubeChannels = [
    "UCQN2DsjnYH60SFBIA6IkNwg",
    "UCyInWbfnusRozzHDh7cKuQA",
    "UCyBZ1F8ZCJVKSIJPrLINFyA",
    "UC286ntgASMskhPIJQebJVvA",
    "UCJ6q9Ie29ajGqKApbLqfBOg",
    "UCPPAYs04kwfXcHnerm_ueFw",
    "UC6Om9kAkl32dWlDSNlDS9Iw",
    "UCz4A6ALhUVHuiXzoJrIGc1Q"
]

Tagslugs = [
    "application-scurity",
    "hacking",
    "infosec",
    "cybersecurity",
    "ctf",
    "penetration-testing",
    "writeup",
    "tryhackme",
    "vulnhub",
    "security",
    "bug-hunter",
    "bug-bounty",
    "info-sec-writeups",
    "hackthebox-writeup",
    "api-security"
]

# Function to get channel videos from YouTube
# Function to get channel videos from YouTube
def get_channel_videos(channel_id):
    youtube = build('youtube', 'v3', developerKey=YOUTUBE_API_KEY)
    next_page_token = None  # Initialize next_page_token here
    videos = []

    while True:
        res = youtube.playlistItems().list(
            playlistId=channel_id,
            part='snippet',
            maxResults=50,
            pageToken=next_page_token
        ).execute()

        videos += res.get('items', [])
        next_page_token = res.get('nextPageToken')

        if not next_page_token:
            break

    return videos



# Function to send message to Discord channel
async def send_message_to_channel(message):
    channel = bot.get_channel(int(DISCORD_CHANNEL_ID))
    await channel.send(message)

# Function to send YouTube video details to Discord
async def send_youtube_message(video_title, video_url, video_tags):
    embed = Embed(title="🎬 New Video!", color=0xFF0000)
    embed.add_field(name="Title", value=video_title, inline=False)
    embed.add_field(name="Tags", value=", ".join(video_tags), inline=False)
    embed.add_field(name="Link", value=video_url, inline=False)
    await send_message_to_channel(embed=embed)

# Function to send Medium article details to Discord
async def send_medium_message(article_title, article_url):
    embed = Embed(title="📝 New Article!", color=0x00FF00)
    embed.add_field(name="Title", value=article_title, inline=False)
    embed.add_field(name="Link", value=article_url, inline=False)
    await send_message_to_channel(embed=embed)

# Main function
async def main():
    # Check for new YouTube videos
    for channel_id in YoutubeChannels:
        videos = get_channel_videos(channel_id)
        for video in videos:
            video_id = video['snippet']['resourceId']['videoId']
            video_url = f"https://www.youtube.com/watch?v={video_id}"
            video_title = video['snippet']['title']

            # Check if the video is already in the database
            if not youtube_videos.search(Posts.video_id == video_id):
                # Get video tags
                video_tags = video['snippet'].get('tags', [])



                # Check if any of the video tags match the specified tags
                if any(tag_slug in video_tags for tag_slug in Tagslugs):
                    # Send video details to Discord
                    await send_youtube_message(video_title, video_url, video_tags)

                    # Add the video to the database to avoid duplicates
                    youtube_videos.insert({'video_id': video_id})

                    # Optional: You can add a delay to avoid hitting API rate limits
                    time.sleep(2)

    # Check for new Medium articles
    for tag_slug in Tagslugs:
        url = f"https://medium.com/tag/{tag_slug}/latest"
        response = requests.get(url, headers=headers)
        articles = response.json().get('payload', {}).get('references', {}).get('Post', {}).values()

        for article in articles:
            article_id = article['id']
            article_url = f"https://medium.com/p/{article['slug']}/{article_id}"
            article_title = article['title']

            # Check if the article is already in the database
            if not medium_articles.search(Posts.article_id == article_id):
                # Send article details to Discord
                await send_medium_message(article_title, article_url)

                # Add the article to the database to avoid duplicates
                medium_articles.insert({'article_id': article_id})

                # Optional: You can add a delay to avoid hitting API rate limits
                time.sleep(2)

# Bot event to execute the 'main' function when the bot is ready
@bot.event
async def on_ready():
    print(f'Logged in as {bot.user.name} ({bot.user.id})')
    await main()

# Run the Discord bot
bot.run(DISCORD_BOT_TOKEN)
