# Git Workflow Guide

## Branch Strategy

### Branch Types
- **main**: Production-ready code only
- **develop**: Integration branch for features
- **feature/**: Individual feature development

### Standard Workflow

#### 1. Create Feature Branch
```bash
git checkout develop
git pull origin develop
git checkout -b feature/your-feature-name
```

#### 2. Develop & Commit
```bash
# Make your changes
git add .
git commit -m "feat: your feature description"
git push origin feature/your-feature-name
```

#### 3. Merge to Develop
```bash
git checkout develop
git pull origin develop
git merge feature/your-feature-name
git push origin develop
```

#### 4. Merge to Main (Production)
```bash
git checkout main
git pull origin main
git merge develop
git push origin main
```

#### 5. Cleanup
```bash
git branch -d feature/your-feature-name
git push origin --delete feature/your-feature-name
```

## Emergency Hotfix Workflow

For critical production fixes:

```bash
git checkout main
git checkout -b hotfix/critical-fix
# Make fix
git checkout main
git merge hotfix/critical-fix
git checkout develop
git merge hotfix/critical-fix
git push origin main develop
```

## Benefits of This Workflow

1. **develop** = Testing ground for integration
2. **main** = Always stable and deployable
3. **Features isolated** = No conflicts between developers
4. **Easy rollbacks** = Clean history
5. **Professional standard** = Industry best practice

## Quick Commands

### Start New Feature
```bash
git checkout develop && git pull origin develop && git checkout -b feature/my-new-feature
```

### Finish Feature
```bash
git checkout develop && git merge feature/my-new-feature && git push origin develop
```

### Release to Production
```bash
git checkout main && git merge develop && git push origin main
``` 