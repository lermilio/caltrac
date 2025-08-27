# Caltrac

CalTrac is a personal fitness and nutrition tracker built in **Flutter** with a **Firebase backend**.  
It combines **manual food/drink logging** with **automated WHOOP API data** to help users track calories, macros, and weight over time.  
This project demonstrates skills in **mobile app development, API integration, and backend architecture**.


## 🛠️ Tech Stack
- **Flutter** – cross-platform mobile development  
- **Firebase** – authentication, Firestore, backend functions  
- **WHOOP API** – pulls daily calories burned + workout data  
- **OpenAI API** – parses natural language food/drink entries  
- **GitHub** – version control, CI/CD ready  


##  📱 Progress Tabs

- Users can view Daily, Weekly, and Monthly summaries.
- Fetches live whoop data for current day on each load.
- Ability to navigate to previous, days, weeks, and months. Days with no data will display adequate message. 


<img src="https://github.com/user-attachments/assets/9cdfcf53-48ee-4ff1-bddf-1daf76e6a0d5" width="250"/>
<img src="https://github.com/user-attachments/assets/558b203c-278f-4cff-8e52-38b302dff62b" width="250"/>
<img src="https://github.com/user-attachments/assets/1edff3b0-7808-4a66-b387-c8d5caa1e829" width="250"/>


## 🍽️ Calorie Logging

- Choose between logging calories consumed or extra calories burned (to account for inaccurate whoop readings).
- Entering Calories Consumed: Enter input (item or raw data), along with date -> AI parses natural language input -> Extracts Calories, Protein, Carbs, and Fats -> User confirms data, summary data updates.
- Examples: “10 oz ground beef 93 percent lean” | “Burrito from chipotle with white rice, steak, cheese and guacamole” | “100 cals, 10g protien, 5g carbs, 3g fat".


<img src="https://github.com/user-attachments/assets/7b955590-de83-4e22-b2e4-6b85fbf6a454" width="250"/>
<img src="https://github.com/user-attachments/assets/5db24ad7-8fa9-4881-a7b8-8059604741b0" width="250"/>
<img src="https://github.com/user-attachments/assets/5559a7fc-0a81-4c0d-9e6b-6171d011b38d" width="250"/>


## ⚖️ Weight Logging

- Enter weight and date, click add.
- Delete entries at will.


<img src="https://github.com/user-attachments/assets/4590c6e2-5540-4046-bde9-b61f676bd3d5" width="250"/>
<img src="https://github.com/user-attachments/assets/9efa3cfd-2a44-43c6-8da8-b5cadd82ec62" width="250"/>

## Summaries Updating for Logs

- Demo of flow: User entering calories in and out, and summaries getting updated in real time.


<img src="https://github.com/user-attachments/assets/bd6e6ccc-68d2-4fbe-9bd0-eeef5d4a5ef5" width="250"/>
<img src="https://github.com/user-attachments/assets/1108974c-23b2-458f-9914-673f43f5e89b" width="250"/>



