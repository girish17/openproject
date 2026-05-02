# Upstream Sync Plan: Yojana → OpenProject

This document outlines the plan to sync the Yojana fork with upstream OpenProject changes.

## Current State

| Metric | Value |
|--------|-------|
| **Fork diverged** | February 10, 2026 from OpenProject `dev` branch |
| **Current version** | OpenProject 17.2.0 |
| **Upstream version** | 17.4.0-dev (4,100+ commits ahead) |
| **Yojana custom commits** | ~20 commits |
| **Files changed in yojana** | 314 total (152 non-crowdin, 183 crowdin locale) |

### Yojana-Specific Changes

1. **Whitelabeling** (commit `08e4857e982`): Massive rebranding from "OpenProject" to "Yojana" across 230 files
2. **Boards enhancements** (commit `ce82705ed75`): Kanban renaming, WIP limits, immediate card creation, CSV import/export
3. **Enterprise unlock** (commit `476831f7070`): Team planner enterprise feature unlocked
4. **Community boards** (commit `834e585ec68`): All board types available in Community edition
5. **Portfolio unlock** (commit `3454b52c0fd`): Removed enterprise restrictions from portfolios
6. **Security fixes**: Multiple Sentinel security patches

## Strategy: Merge (Not Rebase)

**Decision**: Use `git merge upstream/dev` to preserve commit history and allow iterative conflict resolution.

**Reason**: ~20 yojana commits are easier to maintain with merge than rebase (which would require replaying all commits).

## Prerequisites

```bash
# Add upstream remote (one-time setup)
git remote add upstream https://github.com/opf/openproject.git

# Fetch latest upstream changes
git fetch upstream
```

## Estimated Effort

**Total Time**: 48-70 hours (~6-9 business days full-time)

| Phase | Description | Hours |
|-------|-------------|-------|
| Phase 1 | Whitelabeling refactor (prepare) | 3-4 |
| Phase 2 | Enterprise/EE overrides | 4-6 |
| Phase 3 | Portfolio management | 3-5 |
| Phase 4 | Boards module (most complex) | 15-20 |
| Phase 5 | Locale files (main + modules) | 5-7 |
| Phase 6 | Branding assets | 1-2 |
| Phase 7 | Crowdin locales (automated) | 2-3 |
| Phase 8 | Post-merge testing & validation | 10-15 |
| Phase 9 | Docker build & deployment | 1-2 |

## Detailed Plan

### Phase 1: Whitelabeling Refactor (BEFORE Merge)

**Goal**: Convert hardcoded "Yojana" references to configurable ENV-based system to reduce future conflicts.

#### 1.1 Create Branding Module

**New file**: `lib/yojana/branding.rb`

```ruby
module Yojana
  class Branding
    def self.name
      ENV.fetch("YOJANA_BRAND_NAME", "Yojana")
    end

    def self.short_name
      ENV.fetch("YOJANA_BRAND_SHORT_NAME", "yojanaā")
    end

    def self.url
      ENV.fetch("YOJANA_BRAND_URL", "https://yojana.girishm.info")
    end

    def self.support_email
      ENV.fetch("YOJANA_SUPPORT_EMAIL", "support@yojana.girishm.info")
    end
  end
end
```

#### 1.2 Update Settings Definition

Modify `config/constants/settings/definition.rb`:

```ruby
app_title: {
  default: -> { Yojana::Branding.short_name },
  format: :string
},
software_name: {
  default: -> { Yojana::Branding.name },
  format: :string
},
software_url: {
  default: -> { Yojana::Branding.url },
  format: :string
}
```

#### 1.3 Update Docker Deployment

Update `bin/build-docker-azure` or Azure VM run command:

```bash
docker run -d --name yojana --restart unless-stopped \
  -p 8080:80 \
  -e SECRET_KEY_BASE="$(openssl rand -hex 64)" \
  -e YOJANA_BRAND_NAME="Yojana" \
  -e YOJANA_BRAND_URL="https://yojana.girishm.info" \
  girish17/yojana:dev-azure
```

**Time**: 3-4 hours

---

### Phase 2: Execute Merge

```bash
# Create backup and sync branch
git checkout dev
git branch backup-pre-upstream-sync-$(date +%Y%m%d)
git checkout -b upstream-sync-17.4

# Merge upstream
git merge upstream/dev --no-commit --no-ff
```

Expected: Conflicts in ~152 non-crowdin files.

---

### Phase 3: Conflict Resolution by Priority

#### Priority 1: Enterprise/EE Overrides (4-6 hours)

**Files**:
- `config/initializers/menus.rb`
- `config/initializers/permissions.rb`
- `config/initializers/homescreen.rb`
- `config/initializers/ee_dev_override.rb` (yojana new file)

**Strategy**: Keep yojana's enterprise unlock changes, accept upstream functional changes around them.

```bash
# For each conflicting file
git checkout --ours config/initializers/menus.rb
# Manually merge upstream changes around yojana's unlocks
git add config/initializers/menus.rb
```

**Potential Issue**: Upstream may have changed how enterprise features work in 17.3/17.4.

**Resolution**: Review upstream's new enterprise check mechanism and adapt yojana's unlock approach.

---

#### Priority 2: Portfolio Management (3-5 hours)

**Files** (10):
- `app/controllers/portfolios/**`
- `app/views/portfolios/**`
- `lib/api/v3/portfolios/**`

**Strategy**: Keep yojana's enterprise removals, accept upstream refactoring.

**Potential Issue**: Upstream 17.3+ may have refactored portfolio code.

**Resolution**: Apply yojana's enterprise removal pattern to upstream's new code structure.

---

#### Priority 3: Boards Module (15-20 hours) - HIGHEST COMPLEXITY

**Critical Challenge**: OpenProject 17.3 added native Action boards in Community edition. Both codebases modified boards differently.

**Files**: 24+ Ruby files + 14 frontend files

Key conflicting files:
- `modules/boards/app/controllers/boards/boards_controller.rb`
- `modules/boards/app/models/board.rb`
- `modules/boards/lib/api/v3/boards/**`
- `frontend/src/app/features/boards/**`

**Strategy**:

1. **Start with upstream's version** for board architecture:
   ```bash
   git checkout --theirs modules/boards/
   ```

2. **Layer yojana custom features on top**:
   - CSV import/export functionality
   - WIP limits
   - Kanban renaming
   - Immediate card creation

3. **Test thoroughly**:
   - All board types work
   - CSV import/export functions
   - WIP limits enforce correctly

**Potential Issues**:

| Issue | Resolution |
|-------|------------|
| Upstream refactored board models | Study upstream's new architecture before adding yojana features |
| Frontend conflicts in TypeScript | Use upstream's board components as base, add yojana UI enhancements |
| CSV import/export conflicts | Keep yojana's implementation, adapt to upstream's new board data model |
| API changes | Update yojana's board API extensions to match upstream 17.4 API structure |

**Fallback Plan**: If conflicts are unresolvable, temporarily disable yojana board features, merge upstream, then re-implement.

---

#### Priority 4: Main Locale File (3-4 hours)

**File**: `config/locales/en.yml`

**Strategy**: Accept upstream translation updates, preserve yojana branding strings.

```bash
git checkout --merge config/locales/en.yml
# Manually resolve: keep yojana branding, accept upstream translation improvements
```

**Potential Issue**: Large number of translation additions from upstream.

**Resolution**: Use `git checkout --ours` for branding-related keys, `git checkout --theirs` for translation improvements.

---

#### Priority 5: Module Locale Files (2-3 hours)

~20 module `config/locales/en.yml` files.

**Strategy**: Similar to main locale - preserve branding, accept upstream updates.

---

#### Priority 6: Crowdin Locale Files (2-3 hours)

183 files - mostly automated.

**Strategy**:
```bash
# Accept ours for crowdin files (preserve yojana branding)
git checkout --ours config/locales/crowdin/*.yml
git add config/locales/crowdin/*.yml
```

**Potential Issue**: Some crowdin files may have structural changes from upstream.

**Resolution**: Use `git merge --abort` if needed, then handle crowdin files individually.

---

#### Priority 7: Branding Assets (1-2 hours)

**Files**:
- `app/assets/images/icon_logo.svg`
- `app/assets/images/logo_yojana*.png`

**Strategy**: Keep yojana logos, accept any upstream logo updates as separate files.

---

### Phase 4: Post-Merge Validation

#### 4.1 Code Quality Checks

```bash
bundle exec rubocop
cd frontend && npx eslint src/ && cd ..
```

**Potential Issue**: New upstream code may fail yojana's linting rules.

**Resolution**: Fix linting errors, or adjust `.rubocop.yml` / `frontend/eslint.config.mjs` if needed.

---

#### 4.2 Database Migration

```bash
bundle exec rake db:migrate
bundle exec rake db:structure:dump
```

**Potential Issue**: Upstream migrations may conflict with yojana's schema changes.

**Resolution**: Review migration conflicts, ensure yojana custom fields/tables are preserved.

---

#### 4.3 Functional Testing Checklist

| Feature | Test Case | Estimated Time |
|---------|-----------|----------------|
| **Boards** | Create all board types (Action, Kanban, etc.) | 2 hours |
| **Boards** | CSV import/export | 1 hour |
| **Boards** | WIP limits functionality | 1 hour |
| **Boards** | Immediate card creation | 30 mins |
| **Portfolios** | Create/view portfolios | 1 hour |
| **Team Planner** | Verify unlocked in Community | 30 mins |
| **Branding** | Check yojana name throughout UI | 1 hour |
| **Branding** | Verify ENV variable override works | 1 hour |
| **General** | Run RSpec test suite | 4 hours |
| **General** | Run frontend tests | 2 hours |

**Total Testing Time**: 10-15 hours

---

#### 4.4 Docker Build Test

```bash
./bin/build-docker-azure --push
```

**Potential Issue**: New upstream dependencies may fail Docker build.

**Resolution**: Update `docker/prod/Dockerfile` to handle new dependencies, check build logs for specific errors.

---

## Possible Issues and Resolutions

### Issue 1: Boards Module Conflict Nightmare

**Probability**: HIGH (95%)

**Description**: Both yojana and upstream 17.3 implemented community boards differently. The resulting conflict could be extensive.

**Resolution Steps**:
1. Create a separate test branch: `git checkout -b boards-conflict-test`
2. Analyze upstream's community boards implementation: Study commits between 17.2 and 17.4
3. Identify yojana's unique features: CSV import/export, WIP limits, Kanban renaming
4. Re-implement yojana features on upstream's architecture
5. Test each feature individually before marking conflict resolved

**Fallback**: Temporarily remove yojana board customizations, merge upstream, create new issue to re-implement features.

---

### Issue 2: Locale File Merge Hell

**Probability**: MEDIUM (60%)

**Description**: 183 crowdin locale files with yojana branding vs upstream translation updates.

**Resolution Steps**:
1. For crowdin files, use `git checkout --ours` to preserve yojana branding
2. For main `en.yml`, carefully merge: keep yojana branding keys, accept upstream structural changes
3. Consider using a script to automate crowdin file resolution:
   ```bash
   for file in config/locales/crowdin/*.yml; do
     git checkout --ours "$file"
     git add "$file"
   done
   ```

---

### Issue 3: Upstream Changed Enterprise Feature Mechanism

**Probability**: MEDIUM (50%)

**Description**: Upstream 17.3+ may have changed how enterprise features are checked/restricted.

**Resolution Steps**:
1. Study upstream's new enterprise check mechanism (look at `app/controllers/application_controller.rb`, `lib/` files)
2. Adapt yojana's unlock approach to new mechanism
3. May need to remove yojana's old approach and implement new unlock pattern

---

### Issue 4: Database Migration Conflicts

**Probability**: LOW (30%)

**Description**: Upstream migrations may conflict with yojana's schema.

**Resolution Steps**:
1. Run `bundle exec rake db:migrate:status` to see pending/failed migrations
2. If conflict, check `db/schema.rb` for discrepancies
3. Manually resolve by ensuring yojana custom tables/fields are preserved
4. Test with fresh database: `bundle exec rake db:drop db:create db:migrate`

---

### Issue 5: Frontend Build Failures

**Probability**: MEDIUM (40%)

**Description**: Upstream 17.3/17.4 may have updated frontend dependencies causing build failures.

**Resolution Steps**:
1. Check `frontend/package.json` for dependency conflicts
2. Run `cd frontend && rm -rf node_modules && npm ci`
3. Fix any peer dependency warnings
4. Update yojana's frontend code to match upstream's new patterns

---

### Issue 6: Docker Image Build Fails

**Probability**: MEDIUM (40%)

**Description**: New upstream dependencies may not install in Docker build.

**Resolution Steps**:
1. Check build logs for specific failures
2. Update `docker/prod/Dockerfile` to install missing system dependencies
3. Ensure `Gemfile.lock` is up-to-date: `bundle install && git add Gemfile.lock`
4. Rebuild with verbose output: `docker build --progress=plain -f docker/prod/Dockerfile .`

---

### Issue 7: Tests Fail After Merge

**Probability**: HIGH (70%)

**Description**: Upstream changes may break yojana-specific functionality.

**Resolution Steps**:
1. Run specific test suites: `bundle exec rspec spec/models/board_spec.rb`
2. Fix failing tests by updating yojana features to work with upstream code
3. If test is for upstream functionality, ensure it passes with yojana's changes
4. Consider temporarily skipping yojana-specific tests if they need major rework

---

### Issue 8: Performance Regression

**Probability**: LOW (20%)

**Description**: Upstream changes may introduce performance issues.

**Resolution Steps**:
1. Monitor application logs after deployment
2. Use Azure VM monitoring tools
3. Profile slow endpoints: `bundle exec rack-mini-profiler`
4. Report upstream performance issues if identified

---

## Commands Cheat Sheet

### Setup
```bash
git checkout dev
git branch backup-pre-upstream-sync-$(date +%Y%m%d)
git checkout -b upstream-sync-17.4
git remote add upstream https://github.com/opf/openproject.git  # one-time
git fetch upstream
```

### Merge
```bash
git merge upstream/dev --no-commit --no-ff
```

### During Conflict Resolution
```bash
git status                                          # See conflicted files
git diff --name-only --diff-filter=U                 # List only conflicted files
git checkout --ours <file>                           # Keep yojana version
git checkout --theirs <file>                         # Accept upstream version
git add <file>                                       # Mark resolved
git checkout --merge <file>                          # Interactive merge

# Bulk operations
git checkout --ours config/locales/crowdin/*.yml     # Preserve all crowdin branding
git add config/locales/crowdin/*.yml

# Abort if things go wrong
git merge --abort
```

### After Resolving All Conflicts
```bash
git commit -m "Merge upstream/dev into yojana (OpenProject 17.4)"
git push origin upstream-sync-17.4
```

### Testing
```bash
bundle install && cd frontend && npm ci && cd ..
bundle exec rake db:migrate
bin/dev  # Manual testing
bundle exec rspec  # Run tests
cd frontend && npm test && cd ..  # Frontend tests
```

### Deploy
```bash
./bin/build-docker-azure --push
# On Azure VM:
docker pull girish17/yojana:dev-azure
docker rm -f yojana
docker run -d --name yojana --restart unless-stopped \
  -p 8080:80 \
  -e SECRET_KEY_BASE="$(openssl rand -hex 64)" \
  -e YOJANA_BRAND_NAME="Yojana" \
  -e YOJANA_BRAND_URL="https://yojana.girishm.info" \
  girish17/yojana:dev-azure
```

---

## Decision Points

1. **When to sync**: Wait for OpenProject 17.4 stable (est. mid-May 2026) or 17.4.1/17.4.2 (bug fix releases, est. late May 2026)

2. **Whitelabeling**: Refactor BEFORE merge (recommended) or handle during merge

3. **Boards module**: Keep all yojana customizations (15-20 hour effort) or drop some if upstream now provides equivalent features natively

4. **Testing**: Run full test suite locally before pushing, or rely on CI/CD after push

---

## Timeline Recommendation

### Week 1: Preparation (if whitelabeling refactor not done yet)
- Day 1-2: Phase 1 (whitelabeling config)
- Day 3-4: Phase 2 (Enterprise overrides) + Phase 3 (Portfolios)
- Day 5: Phase 7 (Crowdin locales) + Phase 6 (Branding assets)

### Week 2: Core Merge (CRITICAL)
- Day 1-3: Phase 4 (Boards module - allocate majority of time here)
- Day 4: Phase 5 (Locale files)
- Day 5: Phase 8.1 + 8.2 (Code quality + DB migration)

### Week 3: Testing & Deployment
- Day 1-3: Phase 8.3 (Functional testing)
- Day 4: Phase 8.4 (Docker build test)
- Day 5: Deploy to Azure VM, monitor

---

## References

- OpenProject Release Notes: https://www.openproject.org/docs/release-notes/
- OpenProject 17.3 Release: https://www.openproject.org/docs/release-notes/17-3-0/
- OpenProject Roadmap: https://community.openproject.org/projects/openproject/roadmap
- Yojana Azure Deployment: `docs/azure-deployment.md` (this repo)
- Yojana Whitelabeling: `docs/whitelabeling.md` (to be created)
