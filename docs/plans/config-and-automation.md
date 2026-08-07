# Preparation for configurable settings and headless automation

# Config

Instead of hard coding values in the game files, we should introduce a config system that allows values to be configured. This will allow for customization, extension, and difficulty settings later.

# Automation

For balancing and testing the AI, we need to be able to run the game in headless mode, and capture information about outcomes: damage, kills, locations cleared, gold, etc. That means some kind of logging system, either to log files or a SQLite db.