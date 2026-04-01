# rep-counter
Pull-up and push up counter
# Rep Counter

A minimal, mobile-first web app for tracking pull-up and push-up workouts. Built as a single HTML file with no dependencies beyond Chart.js for trend visualization.

## Features

- **Pull-up & push-up tracking** with one-tap counting and per-set logging
- **Exercise variants** — Standard/Eccentric for pull-ups; Standard/Diamond/Archer for push-ups
- **Rest timer** with configurable duration and skip option
- **Calendar heatmap** showing daily volume by exercise, with month navigation
- **30-day trend charts** for total volume and average reps per set
- **Workout history** with filtering by exercise type
- **Dark/light mode** with system preference detection
- **Persistent storage** via localStorage — data survives across sessions
- **JSON export** for backup or analysis
- **PWA-ready** — installable to your phone's home screen for a native app experience

## Getting Started

### Deploy to Vercel (recommended)

1. Fork or clone this repo
2. Go to [vercel.com](https://vercel.com) → New Project → Import this repo
3. Click Deploy — no build config needed

### Deploy to GitHub Pages

1. Push this repo to GitHub
2. Go to Settings → Pages → Source: `main` branch, `/ (root)`
3. Your site will be live at `https://<username>.github.io/rep-counter/`

### Install on iPhone

1. Open the deployed URL in Safari
2. Tap Share → Add to Home Screen
3. Launch from your home screen — runs full-screen without browser chrome

## Usage

### Counting Reps

1. Select **Pull-Ups** or **Push-Ups** at the top
2. Choose a variant (Standard, Eccentric, Diamond, Archer)
3. Tap the big button for each rep
4. Tap **Finish Set** to log the set and start the rest timer
5. Repeat for all sets, then tap **Save Workout**

You can switch between pull-ups and push-ups mid-workout — sets are color-coded and tracked separately.

### Stats

- **Calendar** — days with workouts are highlighted (teal for pull-ups, brown for push-ups, split for both)
- **30-Day Volume** — stacked bar chart of daily reps
- **30-Day Avg Reps/Set** — line chart tracking per-set performance trends

### Settings

| Setting | Default | Description |
|---|---|---|
| Rest timer | 90s | Countdown between sets |
| Pull-up target | 10 | Goal reps per set |
| Push-up target | 20 | Goal reps per set |

## Tech Stack

- Single static HTML file — no build tools, no framework
- [Chart.js](https://www.chartjs.org/) for trend visualization (CDN)
- [Satoshi](https://www.fontshare.com/fonts/satoshi) typeface (Fontshare CDN)
- localStorage for persistence
- Responsive design tested at 375px (iPhone SE) through 1280px+

## Data

All data is stored in your browser's localStorage under the key `repcounter_v2`. Use the **Export JSON** button in Settings to back up your workout history. Data is tied to the domain — don't change your deployment URL or you'll lose history.

## License

MIT
