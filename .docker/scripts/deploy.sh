#!/usr/bin/env bash
IFS=$'\n\t'
set -euo pipefail

# Ensure lagoon environment is set with the least destructive default.
LAGOON_ENVIRONMENT_TYPE=${LAGOON_ENVIRONMENT_TYPE:-production}

# The location of the application directory.
APP="${APP:-/app}"

echo "Running Deploy"
echo "Environment type: $LAGOON_ENVIRONMENT_TYPE"

# Ensure tmp folder always exists.
mkdir -p "$APP/web/sites/default/files/private/tmp"

BACKUP_TIMESTAMP=$(date +%Y-%m-%d_%T)

create_test_users () {
  if [[ "$LAGOON_ENVIRONMENT_TYPE" != "production" ]]; then

    # Creating a Group Admin test user.
    PACSON_GA_USER="kate.swayne+pacsongroupadmin@salsadigital.com.au"
    if drush uinf --mail=$PACSON_GA_USER --fields=name | grep -q "qagroupadmin"; then
      echo "===> Group Admin test user exists, skipping."
    else
      echo "===> Creating a Group Admin test user."
      drush ucrt qagroupadmin --mail=$PACSON_GA_USER --password="salsadigital"
      drush urol group_member_admin qagroupadmin
    fi


    # Creating an Editor test user.
    PACSON_ED_USER="kate.swayne+pacsoneditor@salsadigital.com.au"
    if drush uinf --mail=$PACSON_ED_USER --fields=name | grep -q "qaeditor"; then
      echo "===> Editor test user exists, skipping."
    else
      echo "===> Creating a Editor test user."
      drush ucrt qaeditor --mail=$PACSON_ED_USER --password="salsadigital"
      drush urol editor qaeditor
    fi

    # Creating a qaadmin test user.
    PACSON_QA_USER="kate.swayne+pacsonadmin@salsadigital.com.au"
    if drush uinf --mail=$PACSON_QA_USER --fields=name | grep -q "qaadmin"; then
      echo "===> qaadmin test user exists, skipping."
    else
      echo "===> Creating a qaadmin test user."
      drush ucrt qaadmin --mail=$PACSON_QA_USER --password="salsadigital"
      drush urol site_admin qaadmin
    fi

    # Creating a qasysadmin test user.
    PACSON_QASA_USER="kate.swayne+qasysadmin@salsadigital.com.au"
    if drush uinf --mail=$PACSON_QASA_USER --fields=name | grep -q "qasysadmin"; then
      echo "===> qasysadmin test user exists, skipping."
    else
      echo "===> Creating a qasysadmin test user."
      drush ucrt qasysadmin --mail=$PACSON_QASA_USER --password="salsadigital"
      drush urol administrator qasysadmin
    fi

    # Creating a forum test user.
    PACSON_QAFO_USER="kate.swayne+qaforumuser@salsadigital.com.au"
    if drush uinf --mail=$PACSON_QAFO_USER --fields=name | grep -q "qaforumuser"; then
      echo "===> qaforumuser test user exists, skipping."
    else
      echo "===> Creating a qaforumuser test user."
      drush ucrt qaforumuser --mail=$PACSON_QAFO_USER --password="salsadigital"
    fi

    echo "===> Completed creating test users."
  fi
}

# Database updates, cache rebuild, optional config imports.
common_deploy () {

  drush cache:rebuild
  drush updatedb -y

  if [[ -f /app/config/sync/system.site.yml ]] and [[ "$LAGOON_ENVIRONMENT_TYPE" != "local" ]]; then
    echo "===> Import production configuration."
    drush config:import -y --source=/app/config/sync
  fi

  if [[ "$LAGOON_ENVIRONMENT_TYPE" != "production" ]]; then
    if [[ -f /app/config/sync/system.site.yml ]]; then
      echo "===> Import development configuration override."
      drush config:import -y --partial --source=/app/config/dev
    fi
  fi

  echo "Cleaning up database backup files"
  find /tmp -type f -name '*.sql.gz' -mtime +1 -delete

}

if [[ "$LAGOON_ENVIRONMENT_TYPE" = "production" ]]; then

  echo "Executing production deployment."
  if drush status --fields=bootstrap | grep "Successful"; then
    echo "Making a database backup."
    # shellcheck disable=SC2086
    mkdir -p "$APP/web/sites/default/files/private/backups/" && drush sql:dump --gzip --result-file="$APP/web/sites/default/files/private/backups/pre-deploy-dump.sql"
    common_deploy
  else
    echo "Drupal is not installed or not operational."
  fi

else

  echo "Executing non-production deployment."

  if ! drush status --fields=bootstrap | grep "Successful"; then
    echo "Drupal is not installed or not operational."

    if [[ "$LAGOON_ENVIRONMENT_TYPE" = "local" ]]; then
      echo "Drupal is not installed locally, try ahoy install or add a database dump file 'db.sql' into the .data folder on your local and re-run ahoy build."
      if [[ -f ".data/db.sql" ]]; then
        drush sql-drop --yes
        drush sql-cli < /app/.data/db.sql
        echo "Imported database from .data/db.sql file."
        common_deploy
        ## Adding test users in non-production.
        create_test_users
      fi
    else
      # In a non-functioning development site, import the database from production before running import.
      # Note, this would destroy data in a dev site that was just broken temporarily. Review?
      # shellcheck disable=SC2086
      echo "===> Importing production database."
      drush --alias-path=/app/drush @lagoon.${LAGOON_PROJECT}-production sql:dump --gzip --result-file=/tmp/sync.$BACKUP_TIMESTAMP.sql -y
      drush -y core:rsync @lagoon.${LAGOON_PROJECT}-production:/tmp/sync.$BACKUP_TIMESTAMP.sql.gz /tmp/
      gunzip < /tmp/sync.$BACKUP_TIMESTAMP.sql.gz | drush sql:cli
      rm -f /tmp/sync.$BACKUP_TIMESTAMP.sql.gz
      common_deploy

      ## Adding test users in non-production.
      create_test_users
    fi
  else
    echo "Drupal is installed already, skip database import."
    common_deploy

    ## Adding test users in non-production.
    create_test_users
  fi

fi

echo "Finished running Deploy."
