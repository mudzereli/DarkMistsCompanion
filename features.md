## ✨ Features

The Dark Mists Mudlet Package is designed to **enhance clarity, awareness, and convenience**
while preserving the **core text-based gameplay** of Dark Mists.

> **Design Philosophy**  
> - Focuses on readability and situational awareness  
> - Avoids automation, PvP advantages, or gameplay decision-making  
> - Enhances presentation without altering game balance  

---

## 💬 Chat History

- Separate console window for communication
- Supported channels:
  - `say`
  - `tell`
  - `gtell`
  - `yell`
  - `ooc`
  - `house`
- **Not supported:**
  - `brand`
  - Any other custom channels

---

## 👥 Who Window

- Displays the most recent output from the `who` command
- See who is online without scrolling chat history
- Automatically refreshes when new `who` output is detected

---

## ✨ Affects Window

- Displays the most recent output from:
  - `affects`
  - `score`
- Updates at a rate roughly equivalent to in-game time
- Improves awareness of:
  - Active buffs
  - Expired or expiring effects

---

## 📊 Status Bars

- Real-time bars for:
  - **HP**
  - **Mana**
  - **Movement**
- Enemy HP bar for current combat target
- XP bar:
  - Requires `prompt tnl` to be enabled
- Compatible with all class prompts, including Berserker
  - Rage bar not yet implemented

---

## 🧾 Item Tracker

- Brings the Dark Mists website item lookup directly into the game
- Click an item to view base statistics
- Supported sources:
  - Your equipment
  - Other players
  - NPCs
  - Looting
  - Inventory
  - Containers
  - Shops
- **Not supported:**
  - Ground items

---

## 🗺️ Fully Interactable Colored Map

- Uses Mudlet’s built-in mapping system to detect your in-game location
- Roughly **15,000 rooms** mapped
- Map areas correspond to in-game areas
- Maps can be viewed even while offline

---

## 📍 Map Destinations

- Named, persistent navigation using Mudlet pathfinding
- Save rooms as keywords and walk to them with a command
- Examples:
  - `goto gms` → Walks to Glyndane Market Square
  - `goto area <area name>` → Partially supported
    - Entry point is not guaranteed

---

## 🖱️ Clickable Text

Clickable shortcuts are provided for:

- Room directions
- Quest commands
- Practices
- Training
- Auction house

---

## 🎲 Stat Roller

- Assists with maximizing stats during character creation
- Provides fast, readable rolls without automation

---

## 🚧 Planned Features (Future Releases)

### 💬 Chat History
- Clickable player names
- Example:
  - Clicking `Megaman` in  
    `[OOC] Megaman: test`  
    pre-fills:
    ```
    ooc Megaman 
    ```
- Makes continuing conversations faster and smoother

---

### 👥 Who Window
- Compact display mode

---

### 📊 Status Bars
- Rage bar for Berserkers
- Thirst and hunger indicators
- Gold and silver display

---

### 📍 Map Destinations
- Improved `goto area` pathing logic
