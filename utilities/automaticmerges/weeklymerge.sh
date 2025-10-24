#!/usr/bin/env bash
set -e

bash ./utilities/automaticmerges/weeklymerge/automatic-message-maintenance-weekly.sh
bash ./utilities/automaticmerges/weeklymerge/automatic-update-changelog.sh.sh
bash ./utilities/automaticmerges/weeklymerge/automatic-message-hot-fix-weekly.sh
bash ./utilities/automaticmerges/weeklymerge/automatic-update-hot-fix.sh
bash ./utilities/automaticmerges/weeklymerge/automatic-message-hot-fix-master-weekly.sh
bash ./utilities/automaticmerges/weeklymerge/automatic-update-hot-fix-master.sh
