## 2025-04-16 - [SQL Injection via String Interpolation in update_all]
**Vulnerability:** Found string interpolation directly inside `update_all` calls in `app/models/work_package/time_entries_cleaner.rb` and `app/models/work_packages/costs.rb`.
**Learning:** Even though IDs are usually integers, passing user-supplied IDs (e.g. `to_do[:reassign_to_id]`) through string interpolation into ActiveRecord's `update_all` creates a critical SQL injection risk.
**Prevention:** Always use Rails hash syntax (e.g., `{ entity_id: reassign_to.id }`) for assignments in `update_all` to ensure proper parameterization.
