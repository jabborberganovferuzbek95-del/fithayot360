# API ma'lumotnomasi (v3)

Jonli hujjat: `GET /docs`. Mashinaviy shakl: [openapi.json](openapi.json).

Umumiy: `Authorization: Bearer <access_token>` (🔒); vaqtlar UTC ISO-8601; xatoda `{"detail": "<xabar>"}`; `Idempotency-Key` sarlavhasi: `POST /activities`, `/sessions/{id}/logs`, `/water`.

| Guruh | Metod | Yo'l | Tavsif | Auth |
|---|---|---|---|---|
| active | GET | `/activities` | List Activities | 🔒 |
| active | POST | `/activities` | Create Activity | 🔒 |
| active | DELETE | `/activities/{activity_id}` | Delete Activity | 🔒 |
| active | PATCH | `/activities/{activity_id}` | Update Activity | 🔒 |
| admin | POST | `/admin/exercises` | Create Exercise | 🔒 |
| admin | PATCH | `/admin/exercises/{exercise_id}` | Update Exercise | 🔒 |
| auth | POST | `/auth/forgot-password` | Forgot Password |  |
| auth | POST | `/auth/login` | Login |  |
| auth | POST | `/auth/refresh` | Refresh |  |
| auth | POST | `/auth/register` | Register |  |
| auth | POST | `/auth/reset-password` | Reset Password |  |
| catalog | GET | `/activity-types` | Activity Types | 🔒 |
| catalog | GET | `/exercise-categories` | Categories | 🔒 |
| catalog | GET | `/exercises` | List Exercises | 🔒 |
| catalog | GET | `/exercises/{exercise_id}` | Get Exercise | 🔒 |
| dashboard | GET | `/dashboard/today` | Dashboard Today | 🔒 |
| dashboard | GET | `/stats` | Stats | 🔒 |
| habits | GET | `/habit-checks` | List Checks | 🔒 |
| habits | GET | `/habits` | List Habits | 🔒 |
| habits | POST | `/habits` | Create Habit | 🔒 |
| habits | DELETE | `/habits/{habit_id}` | Delete Habit | 🔒 |
| habits | PUT | `/habits/{habit_id}/checks/{day}` | Set Check | 🔒 |
| insights | GET | `/coach/ask` | Coach Ask | 🔒 |
| insights | GET | `/insights` | Insights | 🔒 |
| insights | GET | `/me/summary` | My Summary | 🔒 |
| me | DELETE | `/me` | Delete Me | 🔒 |
| me | GET | `/me` | Get Me | 🔒 |
| me | PATCH | `/me` | Update Me | 🔒 |
| me | GET | `/me/export` | Export Me | 🔒 |
| nutrition | POST | `/admin/recipes` | Create Recipe | 🔒 |
| nutrition | PATCH | `/admin/recipes/{recipe_id}` | Update Recipe | 🔒 |
| nutrition | GET | `/meals` | List Meals | 🔒 |
| nutrition | POST | `/meals` | Add Meal | 🔒 |
| nutrition | DELETE | `/meals/{meal_id}` | Delete Meal | 🔒 |
| nutrition | GET | `/meditation-logs` | List Meditation Logs | 🔒 |
| nutrition | POST | `/meditation-logs` | Add Meditation Log | 🔒 |
| nutrition | GET | `/meditations` | List Meditations | 🔒 |
| nutrition | GET | `/premium/interest` | Premium Status | 🔒 |
| nutrition | POST | `/premium/interest` | Premium Join | 🔒 |
| nutrition | GET | `/recipes` | List Recipes | 🔒 |
| nutrition | GET | `/recipes/{recipe_id}` | Get Recipe | 🔒 |
| plans | GET | `/plans` | List Plans | 🔒 |
| plans | POST | `/plans` | Create Plan | 🔒 |
| plans | DELETE | `/plans/{plan_id}` | Delete Plan | 🔒 |
| plans | GET | `/plans/{plan_id}` | Get Plan | 🔒 |
| plans | PATCH | `/plans/{plan_id}` | Update Plan | 🔒 |
| plans | POST | `/plans/{plan_id}/items` | Add Item | 🔒 |
| plans | DELETE | `/plans/{plan_id}/items/{item_id}` | Delete Item | 🔒 |
| plans | PATCH | `/plans/{plan_id}/items/{item_id}` | Update Item | 🔒 |
| programs | GET | `/programs` | List Programs | 🔒 |
| programs | GET | `/programs/{program_id}` | Get Program | 🔒 |
| progress | GET | `/history` | History | 🔒 |
| progress | GET | `/progress/weekly` | Weekly | 🔒 |
| sessions | GET | `/sessions` | List Sessions | 🔒 |
| sessions | POST | `/sessions` | Start Session | 🔒 |
| sessions | GET | `/sessions/{session_id}` | Get Session | 🔒 |
| sessions | PATCH | `/sessions/{session_id}` | Update Session | 🔒 |
| sessions | POST | `/sessions/{session_id}/logs` | Add Log | 🔒 |
| sessions | DELETE | `/sessions/{session_id}/logs/{log_id}` | Delete Log | 🔒 |
| sessions | PATCH | `/sessions/{session_id}/logs/{log_id}` | Update Log | 🔒 |
| system | GET | `/health` | Health |  |
| wellness | GET | `/goals` | Get Goals | 🔒 |
| wellness | PATCH | `/goals` | Update Goals | 🔒 |
| wellness | GET | `/sleep` | List Sleep | 🔒 |
| wellness | DELETE | `/sleep/{day}` | Delete Sleep | 🔒 |
| wellness | PUT | `/sleep/{day}` | Put Sleep | 🔒 |
| wellness | GET | `/steps` | List Steps | 🔒 |
| wellness | PUT | `/steps/{day}` | Put Steps | 🔒 |
| wellness | GET | `/water` | Water Day | 🔒 |
| wellness | POST | `/water` | Add Water | 🔒 |
| wellness | DELETE | `/water/{water_id}` | Delete Water | 🔒 |
