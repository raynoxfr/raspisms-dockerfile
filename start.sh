#!/usr/bin/bash

INSTALL_DIR="/usr/share/raspisms"
SETTING_DIR="/config"


run_at_startup() {
	printf "Default setting\n"
	if [ -z "$(ls -A $SETTING_DIR)" ];
	then
		printf "Copy in setting folder is empty, need to create it\n"
		cp -a /default-config/* $SETTING_DIR/
		printf "Done\n"
		do_app_config
	else
		printf "Setting folder is not empty, no need to create it\n"
	fi
	do_line


	printf "Create tables into database and user\n"
	if [ "$CREATE_ALL_SETTING" == "true" ]
	then
		export WAIT_HOSTS="${APP_DATABASE_HOST}:3306"
		/wait
		do_phinx
		do_app_user
	else
		printf "Environment variable CREATE_ALL_SETTING not set to true, skip this step\n"
	fi
	do_line

	printf "Start apache\n"
	service apache2 start
	if ! pidof apache2 > /dev/null
	then
		printf "Cannot start apache service."
	else
		printf "Done.\n"
	fi
	do_line

	printf "Start raspisms\n"
	$INSTALL_DIR/bin/start.sh
	if [ ! $? -eq 0 ]
	then
		printf "Cannot start raspisms."
	else
		printf "Done.\n"
	fi
	do_line

	[[ "$CREATE_ALL_SETTING" == "true" ]] && do_show_credentials

	sleep infinity

}


do_line() {
	printf '=%.0s' {1..100}
	printf '\n'
}


do_replace_envar() {
	VAR=$1
	printf "  Replace $VAR : "
	local ENVAL=$(printf '%s\n' "${!VAR}")
	if [ -n "$ENVAL" ]
	then
		ESCAPED_VALUE=$(printf '%s\n' "$ENVAL" | sed -e 's/[]\/$*.^[]/\\&/g');
		sed -i -- 's/%'"$VAR"'%/'"$ESCAPED_VALUE"'/g' * && printf "Done"
	else
		printf "Not defined"
	fi
	printf "\n"

}


do_app_config () {
	printf "Do configuration of RaspiSMS app, with environment variable if exist...\n"

	cd $SETTING_DIR

	export APP_HTTP_PROTOCOL="$(echo $APP_STATIC_HTTP_URL | grep :// | sed -e's,^\(.*://\).*,\1,g')"

	do_replace_envar 'APP_ENV'
	do_replace_envar 'APP_SECRET'

	do_replace_envar 'APP_HTTP_PROTOCOL'
	do_replace_envar 'APP_STATIC_HTTP_URL'
	do_replace_envar 'APP_DIR_HTTP_URL'

	do_replace_envar 'APP_DATABASE_HOST'
	do_replace_envar 'APP_DATABASE_NAME'
	do_replace_envar 'APP_DATABASE_USER'
	do_replace_envar 'APP_DATABASE_PASS'

	do_replace_envar 'APP_MAIL_SMTP_USER'
	do_replace_envar 'APP_MAIL_SMTP_PASS'
	do_replace_envar 'APP_MAIL_SMTP_HOST'
	do_replace_envar 'APP_MAIL_SMTP_TLS'
	do_replace_envar 'APP_MAIL_SMTP_PORT'
	do_replace_envar 'APP_MAIL_FROM'

	do_replace_envar 'APP_URL_SHORTENER'
	do_replace_envar 'APP_URL_SHORTENER_HOST'
	do_replace_envar 'APP_URL_SHORTENER_USER'
	do_replace_envar 'APP_URL_SHORTENER_PASS'

	printf "Done.\n"
}


do_phinx () {
	printf "Do Phinx migrations...\n"
	
	cd $INSTALL_DIR
	php vendor/bin/phinx migrate
	
	printf "\n"
	printf "Done.\n"
}


do_app_user () {
	printf "Create RaspiSMS default user.\n"

	cd $INSTALL_DIR
	APP_USER_ADMIN="true"
	[[ ! -n "${APP_USER_PASSWORD}" ]] && APP_USER_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
	php console.php controllers/internals/Console.php create_update_user --email="$APP_USER_EMAIL" --password="$APP_USER_PASSWORD" --admin="$APP_USER_ADMIN"

	if [ ! $? -eq 0 ]
	then
		printf "\n"
		printf "Error during user generation."
		printf "\n"
		return 1
	fi

	cd $SETTING_DIR
	GENERATED_USER_TEXT="Email: $APP_USER_EMAIL\nPassword: $APP_USER_PASSWORD\nAdmin: $APP_USER_ADMIN\n"

	printf "\n"
	printf "$GENERATED_USER_TEXT" > "credentials"
	printf "  Make credentials file 700\n"
	chmod 700 credentials

	printf "Done\n"
}

do_show_credentials () {
	printf "Here are the credentials of your RaspiSMS installation.\n"
	printf "\n"

	printf "####### RASPISMS USER ######\n"
	cat $SETTING_DIR/credentials
	printf "\n"
	printf "You can find those in $SETTING_DIR/credentials\n"
	printf "############################\n"
	printf "\n"
}

run_at_startup "$@"; exit
