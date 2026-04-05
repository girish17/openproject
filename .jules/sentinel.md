## 2025-04-16 - [SQL Injection via String Interpolation in update_all]
**Vulnerability:** Found string interpolation directly inside `update_all` calls in `app/models/work_package/time_entries_cleaner.rb` and `app/models/work_packages/costs.rb`.
**Learning:** Even though IDs are usually integers, passing user-supplied IDs (e.g. `to_do[:reassign_to_id]`) through string interpolation into ActiveRecord's `update_all` creates a critical SQL injection risk.
**Prevention:** Always use Rails hash syntax (e.g., `{ entity_id: reassign_to.id }`) for assignments in `update_all` to ensure proper parameterization.

## 2025-04-16 - [XSS via Array#join and html_safe]
**Vulnerability:** Found `[...].join.html_safe` pattern in Rails view helpers (e.g., `modules/backlogs/app/helpers/version_settings_helper.rb`).
**Learning:** Using `.join.html_safe` on an array bypasses HTML escaping for all elements within that array, leading to a Cross-Site Scripting (XSS) vulnerability if any of the elements contain user input.
**Prevention:** Always use Rails' built-in `safe_join(array)` instead of `array.join.html_safe` to ensure that each individual element is safely escaped before being joined together.
