# Wizclip

A Mac clipboard history app in the spirit of Windows’ Win+V panel.

Press **⌘⇧V** (or click the menu bar icon) to open a one-column list of your latest copied text and images. History is saved on disk and comes back after a reboot.

## Install to Applications

From this folder:

```bash
./scripts/install.sh
```

That builds a signed **Wizclip.app**, copies it to `/Applications`, and launches it. After that you can open it from Launchpad, Spotlight, or the Applications folder. Use **Open at Login** in the menu-bar ⋯ menu if you want it every time you start the Mac.

To rebuild later after code changes, run the same command again. It replaces the copy in Applications.

A release `.app` is also left at `dist/Wizclip.app` if you want to drag it somewhere yourself.

Copy some text or a screenshot, then press **⌘⇧V**. The newest item is at the top. Press **Enter** or click a row to paste it into the app you were using.

Optional: choose **Allow Auto-Paste…** in the menu bar extra so macOS can send ⌘V for you. Without that permission, choosing an item still puts it on the clipboard.

## Keys

| Key | Action |
| --- | --- |
| ⌘⇧V | Show or hide history |
| ↑ / ↓ | Move selection |
| Enter | Paste selected item |
| Delete | Remove selected item |
| Esc | Close |

## Persistence

Items are stored in:

`~/Library/Application Support/Wizclip/`

Text lives in `history.json`. Images are saved as PNG files next to it. Up to 80 entries are kept.
