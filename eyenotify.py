import asyncio
import subprocess
import logging
import sys

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(message)s',
    stream=sys.stdout
)

class HealthNotifier:
    def __init__(self, interval_minutes: int):
        self.interval_seconds = interval_minutes * 60
        self.title = "Time to stretch! 👁️"
        self.message = "Take a short break from the screen — look away and do a quick stretch."

    async def send_notification(self):
        try:
            proc = await asyncio.create_subprocess_exec(
                'notify-send',
                self.title,
                self.message,
                '--icon=dialog-information',
                '--urgency=critical'
            )
            await proc.wait()
            logging.info("Notification sent.")
        except FileNotFoundError:
            logging.error("Error: notify-send not found. Install package 'libnotify-bin'.")
        except Exception as e:
            logging.error(f"Unknown error: {e}")

    async def start(self):
        logging.info(f"Service started. Interval: {self.interval_seconds / 60} minutes.")
        await self.send_notification()
        
        while True:
            await asyncio.sleep(self.interval_seconds)
            await self.send_notification()

if __name__ == "__main__":
    notifier = HealthNotifier(interval_minutes=20)
    try:
        asyncio.run(notifier.start())
    except KeyboardInterrupt:
        logging.info("Stopping service...")
