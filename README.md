## PHP app scaffolding

This project aims to provide a barebones scaffold for PHP applications.

Clone this repo as a starting point.

To get started run `ahoy init` and provide detail via the prompts
```
Project name: project-name
Type [drupal|wordpress]: drupal
Composer codebase: [y|n]: y
```

At present this scaffold supports either Drupal or Wordpress.

## Non-composer codebases

If you do not initialise with a composer-based codebase you will need to manage database connectivity manually.

## Drupal

Check the settings files in `.docker/assets` for Lagoon settings to use with Drupal.

For local build, add a database dump file into `.data/db.sql` file and execute
`ahoy build`

## Wordpress

Check the `.docker/wordpress/wp-config.php` file for Lagoon settings. This file is copied into images during the build process.

The following addition in `wp-config.php` ensures Wordpress can run on any domain, including local dev domains or edit domains when running with Quant.

```
$protocol = stripos($_SERVER['SERVER_PROTOCOL'],'https') === 0 ? 'https://' : 'http://';
define('WP_SITEURL', $protocol . $_SERVER['HTTP_HOST']);
define('WP_HOME', $protocol . $_SERVER['HTTP_HOST']);
define('FORCE_SSL_ADMIN', false);
```
