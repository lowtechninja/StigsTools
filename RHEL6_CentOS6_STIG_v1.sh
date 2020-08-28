#!/bin/bash
echo "######################################################################"
echo "#              RHEL 6 and CentOS 6 STIG Harding Script               #"
echo "#            By Marko Sykes Thanks to OpenSCAP and Github            #"
echo "######################################################################"
echo "Are you sure you meant to run this script?"
echo "This script does something drastic that you would severely regret if you happened to run this script by mistake!"
echo ""
echo -e "\033[5;31;47mYou have 60 seconds remaining to hit Ctrl+C to cancel this operation\033[0m"
echo ""
#Countdown Timer 
function countdown
{
        local OLD_IFS="${IFS}"
        IFS=":"
        local ARR=( $1 )
        local SECONDS=$((  (ARR[0] * 60 * 60) + (ARR[1] * 60) + ARR[2]  ))
        local START=$(date +%s)
        local END=$((START + SECONDS))
        local CUR=$START

        while [[ $CUR -lt $END ]]
        do
                CUR=$(date +%s)
                LEFT=$((END-CUR))

                printf "\r%02d:%02d:%02d" \
                        $((LEFT/3600)) $(( (LEFT/60)%60)) $((LEFT%60))

                sleep 1
        done
        IFS="${OLD_IFS}"
        echo "        "
}

countdown "00:01:00"
#End of Countdown Timer
#
clear
echo "##########################################"
echo "#     Applying STIGs Please Be Patient   #"
echo "##########################################"

###############################################################################
# BEGIN fix (1 / 114) for 'xccdf_org.ssgproject.content_rule_accounts_max_concurrent_login_sessions'
###############################################################################
(>&2 echo "Remediating rule 1/114: 'xccdf_org.ssgproject.content_rule_accounts_max_concurrent_login_sessions'")

var_accounts_max_concurrent_login_sessions="10"

if grep -q '^[^#]*\<maxlogins\>' /etc/security/limits.d/*.conf; then
	sed -i "/^[^#]*\<maxlogins\>/ s/maxlogins.*/maxlogins $var_accounts_max_concurrent_login_sessions/" /etc/security/limits.d/*.conf
elif grep -q '^[^#]*\<maxlogins\>' /etc/security/limits.conf; then
	sed -i "/^[^#]*\<maxlogins\>/ s/maxlogins.*/maxlogins $var_accounts_max_concurrent_login_sessions/" /etc/security/limits.conf
else
	echo "*	hard	maxlogins	$var_accounts_max_concurrent_login_sessions" >> /etc/security/limits.conf
fi

# END fix for 'xccdf_org.ssgproject.content_rule_accounts_max_concurrent_login_sessions'

###############################################################################
# BEGIN fix (2 / 114) for 'xccdf_org.ssgproject.content_rule_accounts_tmout'
###############################################################################
(>&2 echo "Remediating rule 2/114: 'xccdf_org.ssgproject.content_rule_accounts_tmout'")
(>&2 echo "FIX FOR THIS RULE 'xccdf_org.ssgproject.content_rule_accounts_tmout' IS MISSING!")

# END fix for 'xccdf_org.ssgproject.content_rule_accounts_tmout'

###############################################################################
# BEGIN fix (3 / 114) for 'xccdf_org.ssgproject.content_rule_accounts_umask_etc_profile'
###############################################################################
(>&2 echo "Remediating rule 3/114: 'xccdf_org.ssgproject.content_rule_accounts_umask_etc_profile'")
(>&2 echo "FIX FOR THIS RULE 'xccdf_org.ssgproject.content_rule_accounts_umask_etc_profile' IS MISSING!")

# END fix for 'xccdf_org.ssgproject.content_rule_accounts_umask_etc_profile'

###############################################################################
# BEGIN fix (4 / 114) for 'xccdf_org.ssgproject.content_rule_disable_ctrlaltdel_reboot'
###############################################################################
(>&2 echo "Remediating rule 4/114: 'xccdf_org.ssgproject.content_rule_disable_ctrlaltdel_reboot'")
if [ ! -f /etc/init/control-alt-delete.override ]; then
	# but does have control-alt-delete.conf file,
	if [ -f /etc/init/control-alt-delete.conf ]; then
		# then copy .conf to .override to maintain persistency
		cp /etc/init/control-alt-delete.conf /etc/init/control-alt-delete.override
	fi
fi
sed -i 's,^exec.*$,exec /usr/bin/logger -p authpriv.notice -t init "Ctrl-Alt-Del was pressed and ignored",' /etc/init/control-alt-delete.override

# END fix for 'xccdf_org.ssgproject.content_rule_disable_ctrlaltdel_reboot'

###############################################################################
# BEGIN fix (5 / 114) for 'xccdf_org.ssgproject.content_rule_package_screen_installed'
###############################################################################
(>&2 echo "Remediating rule 5/114: 'xccdf_org.ssgproject.content_rule_package_screen_installed'")

if ! rpm -q --quiet "screen" ; then
    yum install -y "screen"
fi

# END fix for 'xccdf_org.ssgproject.content_rule_package_screen_installed'

###############################################################################
# BEGIN fix (6 / 114) for 'xccdf_org.ssgproject.content_rule_smartcard_auth'
###############################################################################
(>&2 echo "Remediating rule 6/114: 'xccdf_org.ssgproject.content_rule_smartcard_auth'")

# Install required packages
yum -y install esc
yum -y install pam_pkcs11

# Enable pcscd service
/sbin/service "pcscd" enable
/sbin/chkconfig --level 0123456 "pcscd" on

# Configure the expected /etc/pam.d/system-auth{,-ac} settings directly
#
# The code below will configure system authentication in the way smart card
# logins will be enabled, but also user login(s) via other method to be allowed
#
# NOTE: In contrast to Red Hat Enterprise Linux 7 version of this remediation
#       script (based on the testing) it does NOT seem to be possible to use
#       the 'authconfig' command to perform the remediation for us. Because:
#
#       * calling '/usr/sbin/authconfig --enablesmartcard --update'
#	  does not update all the necessary files, while
#
#	* calling '/usr/sbin/authconfig --enablesmartcard --updateall'
#	  discards the necessary changes on /etc/pam_pkcs11/pam_pkcs11.conf
#	  performed subsequently below
#
#	Therefore we configure /etc/pam.d/system-auth{,-ac} settings directly.
#

# Define system-auth config location
SYSTEM_AUTH_CONF="/etc/pam.d/system-auth"
# Define expected 'pam_env.so' row in $SYSTEM_AUTH_CONF
PAM_ENV_SO="auth.*required.*pam_env.so"

# Define 'pam_succeed_if.so' row to be appended past $PAM_ENV_SO row into $SYSTEM_AUTH_CONF
SYSTEM_AUTH_PAM_SUCCEED="\
auth        \[success=1 default=ignore\] pam_succeed_if.so service notin \
login:gdm:xdm:kdm:xscreensaver:gnome-screensaver:kscreensaver quiet use_uid"
# Define 'pam_pkcs11.so' row to be appended past $SYSTEM_AUTH_PAM_SUCCEED
# row into SYSTEM_AUTH_CONF file
SYSTEM_AUTH_PAM_PKCS11="\
auth        \[success=done authinfo_unavail=ignore ignore=ignore default=die\] \
pam_pkcs11.so card_only"

# Define smartcard-auth config location
SMARTCARD_AUTH_CONF="/etc/pam.d/smartcard-auth"
# Define 'pam_pkcs11.so' auth section to be appended past $PAM_ENV_SO into $SMARTCARD_AUTH_CONF
SMARTCARD_AUTH_SECTION="\
auth        [success=done ignore=ignore default=die] pam_pkcs11.so wait_for_card card_only"
# Define expected 'pam_permit.so' row in $SMARTCARD_AUTH_CONF
PAM_PERMIT_SO="account.*required.*pam_permit.so"
# Define 'pam_pkcs11.so' password section
SMARTCARD_PASSWORD_SECTION="\
password    required      pam_pkcs11.so"

# First Correct the SYSTEM_AUTH_CONF configuration
if ! grep -q 'pam_pkcs11.so' "$SYSTEM_AUTH_CONF"
then
	# Append (expected) pam_succeed_if.so row past the pam_env.so into SYSTEM_AUTH_CONF file
	sed -i --follow-symlinks -e '/^'"$PAM_ENV_SO"'/a '"$SYSTEM_AUTH_PAM_SUCCEED" "$SYSTEM_AUTH_CONF"
	# Append (expected) pam_pkcs11.so row past the pam_succeed_if.so into SYSTEM_AUTH_CONF file
	sed -i --follow-symlinks -e '/^'"$SYSTEM_AUTH_PAM_SUCCEED"'/a '"$SYSTEM_AUTH_PAM_PKCS11" "$SYSTEM_AUTH_CONF"
fi

# Then also correct the SMARTCARD_AUTH_CONF
if ! grep -q 'pam_pkcs11.so' "$SMARTCARD_AUTH_CONF"
then
	# Append (expected) SMARTCARD_AUTH_SECTION row past the pam_env.so into SMARTCARD_AUTH_CONF file
	sed -i --follow-symlinks -e '/^'"$PAM_ENV_SO"'/a '"$SMARTCARD_AUTH_SECTION" "$SMARTCARD_AUTH_CONF"
	# Append (expected) SMARTCARD_PASSWORD_SECTION row past the pam_permit.so into SMARTCARD_AUTH_CONF file
	sed -i --follow-symlinks -e '/^'"$PAM_PERMIT_SO"'/a '"$SMARTCARD_PASSWORD_SECTION" "$SMARTCARD_AUTH_CONF"
fi

# Perform /etc/pam_pkcs11/pam_pkcs11.conf settings below
# Define selected constants for later reuse
SP="[:space:]"
PAM_PKCS11_CONF="/etc/pam_pkcs11/pam_pkcs11.conf"

# Ensure OCSP is turned on in $PAM_PKCS11_CONF
# 1) First replace any occurrence of 'none' value of 'cert_policy' key setting with the correct configuration
# On Red Hat Enterprise Linux 6 a space isn't required between 'cert_policy' key and value assignment !!!
sed -i "s/^[$SP]*cert_policy=none;/    cert_policy=ca, ocsp_on, signature;/g" "$PAM_PKCS11_CONF"

# 2) Then append 'ocsp_on' value setting to each 'cert_policy' key in $PAM_PKCS11_CONF configuration line,
# which does not contain it yet
# On Red Hat Enterprise Linux 6 a space isn't required between 'cert_policy' key and value assignment !!!
sed -i "/ocsp_on/! s/^[$SP]*cert_policy=\(.*\);/    cert_policy=\1, ocsp_on;/" "$PAM_PKCS11_CONF"

# END fix for 'xccdf_org.ssgproject.content_rule_smartcard_auth'

###############################################################################
# BEGIN fix (7 / 114) for 'xccdf_org.ssgproject.content_rule_display_login_attempts'
###############################################################################
(>&2 echo "Remediating rule 7/114: 'xccdf_org.ssgproject.content_rule_display_login_attempts'")


# END fix for 'xccdf_org.ssgproject.content_rule_display_login_attempts'

###############################################################################
# BEGIN fix (8 / 114) for 'xccdf_org.ssgproject.content_rule_banner_etc_issue'
###############################################################################
(>&2 echo "Remediating rule 8/114: 'xccdf_org.ssgproject.content_rule_banner_etc_issue'")

login_banner_text="(^You[\s\n]+are[\s\n]+accessing[\s\n]+a[\s\n]+U.S.[\s\n]+Government[\s\n]+\(USG\)[\s\n]+Information[\s\n]+System[\s\n]+\(IS\)[\s\n]+that[\s\n]+is[\s\n]+provided[\s\n]+for[\s\n]+USG-authorized[\s\n]+use[\s\n]+only.[\s\n]*By[\s\n]+using[\s\n]+this[\s\n]+IS[\s\n]+\(which[\s\n]+includes[\s\n]+any[\s\n]+device[\s\n]+attached[\s\n]+to[\s\n]+this[\s\n]+IS\),[\s\n]+you[\s\n]+consent[\s\n]+to[\s\n]+the[\s\n]+following[\s\n]+conditions\:(\\n)*(\n)*-[\s\n]*The[\s\n]+USG[\s\n]+routinely[\s\n]+intercepts[\s\n]+and[\s\n]+monitors[\s\n]+communications[\s\n]+on[\s\n]+this[\s\n]+IS[\s\n]+for[\s\n]+purposes[\s\n]+including,[\s\n]+but[\s\n]+not[\s\n]+limited[\s\n]+to,[\s\n]+penetration[\s\n]+testing,[\s\n]+COMSEC[\s\n]+monitoring,[\s\n]+network[\s\n]+operations[\s\n]+and[\s\n]+defense,[\s\n]+personnel[\s\n]+misconduct[\s\n]+\(PM\),[\s\n]+law[\s\n]+enforcement[\s\n]+\(LE\),[\s\n]+and[\s\n]+counterintelligence[\s\n]+\(CI\)[\s\n]+investigations.(\\n)*(\n)*-[\s\n]*At[\s\n]+any[\s\n]+time,[\s\n]+the[\s\n]+USG[\s\n]+may[\s\n]+inspect[\s\n]+and[\s\n]+seize[\s\n]+data[\s\n]+stored[\s\n]+on[\s\n]+this[\s\n]+IS.(\\n)*(\n)*-[\s\n]*Communications[\s\n]+using,[\s\n]+or[\s\n]+data[\s\n]+stored[\s\n]+on,[\s\n]+this[\s\n]+IS[\s\n]+are[\s\n]+not[\s\n]+private,[\s\n]+are[\s\n]+subject[\s\n]+to[\s\n]+routine[\s\n]+monitoring,[\s\n]+interception,[\s\n]+and[\s\n]+search,[\s\n]+and[\s\n]+may[\s\n]+be[\s\n]+disclosed[\s\n]+or[\s\n]+used[\s\n]+for[\s\n]+any[\s\n]+USG-authorized[\s\n]+purpose.(\\n)*(\n)*-[\s\n]*This[\s\n]+IS[\s\n]+includes[\s\n]+security[\s\n]+measures[\s\n]+\(e.g.,[\s\n]+authentication[\s\n]+and[\s\n]+access[\s\n]+controls\)[\s\n]+to[\s\n]+protect[\s\n]+USG[\s\n]+interests--not[\s\n]+for[\s\n]+your[\s\n]+personal[\s\n]+benefit[\s\n]+or[\s\n]+privacy.(\\n)*(\n)*-[\s\n]*Notwithstanding[\s\n]+the[\s\n]+above,[\s\n]+using[\s\n]+this[\s\n]+IS[\s\n]+does[\s\n]+not[\s\n]+constitute[\s\n]+consent[\s\n]+to[\s\n]+PM,[\s\n]+LE[\s\n]+or[\s\n]+CI[\s\n]+investigative[\s\n]+searching[\s\n]+or[\s\n]+monitoring[\s\n]+of[\s\n]+the[\s\n]+content[\s\n]+of[\s\n]+privileged[\s\n]+communications,[\s\n]+or[\s\n]+work[\s\n]+product,[\s\n]+related[\s\n]+to[\s\n]+personal[\s\n]+representation[\s\n]+or[\s\n]+services[\s\n]+by[\s\n]+attorneys,[\s\n]+psychotherapists,[\s\n]+or[\s\n]+clergy,[\s\n]+and[\s\n]+their[\s\n]+assistants.[\s\n]+Such[\s\n]+communications[\s\n]+and[\s\n]+work[\s\n]+product[\s\n]+are[\s\n]+private[\s\n]+and[\s\n]+confidential.[\s\n]+See[\s\n]+User[\s\n]+Agreement[\s\n]+for[\s\n]+details.$|^I\'ve[\s\n]+read[\s\n]+\&[\s\n]+consent[\s\n]+to[\s\n]+terms[\s\n]+in[\s\n]+IS[\s\n]+user[\s\n]+agreem\'t$)"

# There was a regular-expression matching various banners, needs to be expanded
expanded=$(echo "$login_banner_text" | sed 's/(\\\\\x27)\*/\\\x27/g;s/(\\\x27)\*//g;s/(\^\(.*\)\$|.*$/\1/g;s/\[\\s\\n\][+*]/ /g;s/\\//g;s/[^-]- /\n\n-/g;s/(n)\**//g')
formatted=$(echo "$expanded" | fold -sw 80)

cat <<EOF >/etc/issue
$formatted
EOF

printf "\n" >> /etc/issue

# END fix for 'xccdf_org.ssgproject.content_rule_banner_etc_issue'

###############################################################################
# BEGIN fix (9 / 114) for 'xccdf_org.ssgproject.content_rule_gconf_gdm_set_login_banner_text'
###############################################################################
(>&2 echo "Remediating rule 9/114: 'xccdf_org.ssgproject.content_rule_gconf_gdm_set_login_banner_text'")

login_banner_text="(^You[\s\n]+are[\s\n]+accessing[\s\n]+a[\s\n]+U.S.[\s\n]+Government[\s\n]+\(USG\)[\s\n]+Information[\s\n]+System[\s\n]+\(IS\)[\s\n]+that[\s\n]+is[\s\n]+provided[\s\n]+for[\s\n]+USG-authorized[\s\n]+use[\s\n]+only.[\s\n]*By[\s\n]+using[\s\n]+this[\s\n]+IS[\s\n]+\(which[\s\n]+includes[\s\n]+any[\s\n]+device[\s\n]+attached[\s\n]+to[\s\n]+this[\s\n]+IS\),[\s\n]+you[\s\n]+consent[\s\n]+to[\s\n]+the[\s\n]+following[\s\n]+conditions\:(\\n)*(\n)*-[\s\n]*The[\s\n]+USG[\s\n]+routinely[\s\n]+intercepts[\s\n]+and[\s\n]+monitors[\s\n]+communications[\s\n]+on[\s\n]+this[\s\n]+IS[\s\n]+for[\s\n]+purposes[\s\n]+including,[\s\n]+but[\s\n]+not[\s\n]+limited[\s\n]+to,[\s\n]+penetration[\s\n]+testing,[\s\n]+COMSEC[\s\n]+monitoring,[\s\n]+network[\s\n]+operations[\s\n]+and[\s\n]+defense,[\s\n]+personnel[\s\n]+misconduct[\s\n]+\(PM\),[\s\n]+law[\s\n]+enforcement[\s\n]+\(LE\),[\s\n]+and[\s\n]+counterintelligence[\s\n]+\(CI\)[\s\n]+investigations.(\\n)*(\n)*-[\s\n]*At[\s\n]+any[\s\n]+time,[\s\n]+the[\s\n]+USG[\s\n]+may[\s\n]+inspect[\s\n]+and[\s\n]+seize[\s\n]+data[\s\n]+stored[\s\n]+on[\s\n]+this[\s\n]+IS.(\\n)*(\n)*-[\s\n]*Communications[\s\n]+using,[\s\n]+or[\s\n]+data[\s\n]+stored[\s\n]+on,[\s\n]+this[\s\n]+IS[\s\n]+are[\s\n]+not[\s\n]+private,[\s\n]+are[\s\n]+subject[\s\n]+to[\s\n]+routine[\s\n]+monitoring,[\s\n]+interception,[\s\n]+and[\s\n]+search,[\s\n]+and[\s\n]+may[\s\n]+be[\s\n]+disclosed[\s\n]+or[\s\n]+used[\s\n]+for[\s\n]+any[\s\n]+USG-authorized[\s\n]+purpose.(\\n)*(\n)*-[\s\n]*This[\s\n]+IS[\s\n]+includes[\s\n]+security[\s\n]+measures[\s\n]+\(e.g.,[\s\n]+authentication[\s\n]+and[\s\n]+access[\s\n]+controls\)[\s\n]+to[\s\n]+protect[\s\n]+USG[\s\n]+interests--not[\s\n]+for[\s\n]+your[\s\n]+personal[\s\n]+benefit[\s\n]+or[\s\n]+privacy.(\\n)*(\n)*-[\s\n]*Notwithstanding[\s\n]+the[\s\n]+above,[\s\n]+using[\s\n]+this[\s\n]+IS[\s\n]+does[\s\n]+not[\s\n]+constitute[\s\n]+consent[\s\n]+to[\s\n]+PM,[\s\n]+LE[\s\n]+or[\s\n]+CI[\s\n]+investigative[\s\n]+searching[\s\n]+or[\s\n]+monitoring[\s\n]+of[\s\n]+the[\s\n]+content[\s\n]+of[\s\n]+privileged[\s\n]+communications,[\s\n]+or[\s\n]+work[\s\n]+product,[\s\n]+related[\s\n]+to[\s\n]+personal[\s\n]+representation[\s\n]+or[\s\n]+services[\s\n]+by[\s\n]+attorneys,[\s\n]+psychotherapists,[\s\n]+or[\s\n]+clergy,[\s\n]+and[\s\n]+their[\s\n]+assistants.[\s\n]+Such[\s\n]+communications[\s\n]+and[\s\n]+work[\s\n]+product[\s\n]+are[\s\n]+private[\s\n]+and[\s\n]+confidential.[\s\n]+See[\s\n]+User[\s\n]+Agreement[\s\n]+for[\s\n]+details.$|^I\'ve[\s\n]+read[\s\n]+\&[\s\n]+consent[\s\n]+to[\s\n]+terms[\s\n]+in[\s\n]+IS[\s\n]+user[\s\n]+agreem\'t$)"

# Install GConf2 package if not installed
if ! rpm -q GConf2; then
  yum -y install GConf2
fi

# Expand the login_banner_text value - there was a regular-expression
# matching various banners, needs to be expanded
banner_expanded=$(echo "$login_banner_text" | sed 's/\[\\s\\n\][*+]/ /g;s/\\//g;')

# Set the text shown by the GNOME Display Manager in the login screen
gconftool-2 --direct \
            --config-source "xml:readwrite:/etc/gconf/gconf.xml.mandatory" \
            --type string \
            --set /apps/gdm/simple-greeter/banner_message_text "${banner_expanded}"

# END fix for 'xccdf_org.ssgproject.content_rule_gconf_gdm_set_login_banner_text'

###############################################################################
# BEGIN fix (10 / 114) for 'xccdf_org.ssgproject.content_rule_partition_for_var_log_audit'
###############################################################################
(>&2 echo "Remediating rule 10/114: 'xccdf_org.ssgproject.content_rule_partition_for_var_log_audit'")
(>&2 echo "FIX FOR THIS RULE 'xccdf_org.ssgproject.content_rule_partition_for_var_log_audit' IS MISSING!")

# END fix for 'xccdf_org.ssgproject.content_rule_partition_for_var_log_audit'

###############################################################################
# BEGIN fix (11 / 114) for 'xccdf_org.ssgproject.content_rule_partition_for_tmp'
###############################################################################
(>&2 echo "Remediating rule 11/114: 'xccdf_org.ssgproject.content_rule_partition_for_tmp'")
(>&2 echo "FIX FOR THIS RULE 'xccdf_org.ssgproject.content_rule_partition_for_tmp' IS MISSING!")

# END fix for 'xccdf_org.ssgproject.content_rule_partition_for_tmp'

###############################################################################
# BEGIN fix (12 / 114) for 'xccdf_org.ssgproject.content_rule_partition_for_var'
###############################################################################
(>&2 echo "Remediating rule 12/114: 'xccdf_org.ssgproject.content_rule_partition_for_var'")
(>&2 echo "FIX FOR THIS RULE 'xccdf_org.ssgproject.content_rule_partition_for_var' IS MISSING!")

# END fix for 'xccdf_org.ssgproject.content_rule_partition_for_var'

###############################################################################
# BEGIN fix (13 / 114) for 'xccdf_org.ssgproject.content_rule_partition_for_var_log'
###############################################################################
(>&2 echo "Remediating rule 13/114: 'xccdf_org.ssgproject.content_rule_partition_for_var_log'")
(>&2 echo "FIX FOR THIS RULE 'xccdf_org.ssgproject.content_rule_partition_for_var_log' IS MISSING!")

# END fix for 'xccdf_org.ssgproject.content_rule_partition_for_var_log'

###############################################################################
# BEGIN fix (14 / 114) for 'xccdf_org.ssgproject.content_rule_gconf_gnome_screensaver_idle_activation_enabled'
###############################################################################
(>&2 echo "Remediating rule 14/114: 'xccdf_org.ssgproject.content_rule_gconf_gnome_screensaver_idle_activation_enabled'")
# Install GConf2 package if not installed
if ! rpm -q GConf2; then
  yum -y install GConf2
fi

# Set the screensaver activation in the GNOME desktop after a period of inactivity
gconftool-2 --direct \
            --config-source "xml:readwrite:/etc/gconf/gconf.xml.mandatory" \
            --type bool \
            --set /apps/gnome-screensaver/idle_activation_enabled true

# END fix for 'xccdf_org.ssgproject.content_rule_gconf_gnome_screensaver_idle_activation_enabled'

###############################################################################
# BEGIN fix (15 / 114) for 'xccdf_org.ssgproject.content_rule_gconf_gnome_screensaver_mode_blank'
###############################################################################
(>&2 echo "Remediating rule 15/114: 'xccdf_org.ssgproject.content_rule_gconf_gnome_screensaver_mode_blank'")
# Install GConf2 package if not installed
if ! rpm -q GConf2; then
  yum -y install GConf2
fi

# Set the screensaver mode in the GNOME desktop to a blank screen
gconftool-2 --direct \
            --config-source "xml:readwrite:/etc/gconf/gconf.xml.mandatory" \
            --type string \
            --set /apps/gnome-screensaver/mode blank-only

# END fix for 'xccdf_org.ssgproject.content_rule_gconf_gnome_screensaver_mode_blank'

###############################################################################
# BEGIN fix (16 / 114) for 'xccdf_org.ssgproject.content_rule_gconf_gnome_screensaver_idle_delay'
###############################################################################
(>&2 echo "Remediating rule 16/114: 'xccdf_org.ssgproject.content_rule_gconf_gnome_screensaver_idle_delay'")

inactivity_timeout_value="900"

# Install GConf2 package if not installed
if ! rpm -q GConf2; then
  yum -y install GConf2
fi

# Set the idle time-out value for inactivity in the GNOME desktop to meet the
# requirement
gconftool-2 --direct \
            --config-source "xml:readwrite:/etc/gconf/gconf.xml.mandatory" \
            --type int \
            --set /desktop/gnome/session/idle_delay ${inactivity_timeout_value}

# END fix for 'xccdf_org.ssgproject.content_rule_gconf_gnome_screensaver_idle_delay'

###############################################################################
# BEGIN fix (17 / 114) for 'xccdf_org.ssgproject.content_rule_gconf_gnome_screensaver_lock_enabled'
###############################################################################
(>&2 echo "Remediating rule 17/114: 'xccdf_org.ssgproject.content_rule_gconf_gnome_screensaver_lock_enabled'")
# Install GConf2 package if not installed
if ! rpm -q GConf2; then
  yum -y install GConf2
fi

# Set the screensaver locking activation in the GNOME desktop when the
# screensaver is activated
gconftool-2 --direct \
            --config-source "xml:readwrite:/etc/gconf/gconf.xml.mandatory" \
            --type bool \
            --set /apps/gnome-screensaver/lock_enabled true

# END fix for 'xccdf_org.ssgproject.content_rule_gconf_gnome_screensaver_lock_enabled'

###############################################################################
# BEGIN fix (18 / 114) for 'xccdf_org.ssgproject.content_rule_gconf_gnome_screen_locking_keybindings'
###############################################################################
(>&2 echo "Remediating rule 18/114: 'xccdf_org.ssgproject.content_rule_gconf_gnome_screen_locking_keybindings'")
# Install GConf2 package if not installed
if ! rpm -q GConf2; then
  yum -y install GConf2
fi

# Set the screensaver mode in the GNOME desktop to a blank screen
gconftool-2 --direct \
            --config-source "xml:readwrite:/etc/gconf/gconf.xml.mandatory" \
            --type string \
            --set /apps/gnome_settings_daemon/keybindings/screensaver "<Control><Alt>l"

# END fix for 'xccdf_org.ssgproject.content_rule_gconf_gnome_screen_locking_keybindings'

###############################################################################
# BEGIN fix (19 / 114) for 'xccdf_org.ssgproject.content_rule_gconf_gnome_disable_ctrlaltdel_reboot'
###############################################################################
(>&2 echo "Remediating rule 19/114: 'xccdf_org.ssgproject.content_rule_gconf_gnome_disable_ctrlaltdel_reboot'")
(>&2 echo "FIX FOR THIS RULE 'xccdf_org.ssgproject.content_rule_gconf_gnome_disable_ctrlaltdel_reboot' IS MISSING!")

# END fix for 'xccdf_org.ssgproject.content_rule_gconf_gnome_disable_ctrlaltdel_reboot'

###############################################################################
# BEGIN fix (20 / 114) for 'xccdf_org.ssgproject.content_rule_gconf_gdm_disable_user_list'
###############################################################################
(>&2 echo "Remediating rule 20/114: 'xccdf_org.ssgproject.content_rule_gconf_gdm_disable_user_list'")
# Install GConf2 package if not installed
if ! rpm -q GConf2; then
  yum -y install GConf2
fi

# Disable displaying of all known system users in the GNOME Display Manager's
# login screen
gconftool-2 --direct \
            --config-source "xml:readwrite:/etc/gconf/gconf.xml.mandatory" \
            --type bool \
            --set /apps/gdm/simple-greeter/disable_user_list true

# END fix for 'xccdf_org.ssgproject.content_rule_gconf_gdm_disable_user_list'

###############################################################################
# BEGIN fix (21 / 114) for 'xccdf_org.ssgproject.content_rule_package_aide_installed'
###############################################################################
(>&2 echo "Remediating rule 21/114: 'xccdf_org.ssgproject.content_rule_package_aide_installed'")

if ! rpm -q --quiet "aide" ; then
    yum install -y "aide"
fi

# END fix for 'xccdf_org.ssgproject.content_rule_package_aide_installed'

###############################################################################
# BEGIN fix (22 / 114) for 'xccdf_org.ssgproject.content_rule_aide_periodic_cron_checking'
###############################################################################
(>&2 echo "Remediating rule 22/114: 'xccdf_org.ssgproject.content_rule_aide_periodic_cron_checking'")

if ! rpm -q --quiet "aide" ; then
    yum install -y "aide"
fi

if ! grep -q "/usr/sbin/aide --check" /etc/crontab ; then
    echo "05 4 * * * root /usr/sbin/aide --check" >> /etc/crontab
else
    sed -i '/^.*\/usr\/sbin\/aide --check.*$/d' /etc/crontab
    echo "05 4 * * * root /usr/sbin/aide --check" >> /etc/crontab
fi

# END fix for 'xccdf_org.ssgproject.content_rule_aide_periodic_cron_checking'

###############################################################################
# BEGIN fix (23 / 114) for 'xccdf_org.ssgproject.content_rule_rpm_verify_permissions'
###############################################################################
(>&2 echo "Remediating rule 23/114: 'xccdf_org.ssgproject.content_rule_rpm_verify_permissions'")

# Declare array to hold set of RPM packages we need to correct permissions for
declare -A SETPERMS_RPM_DICT

# Create a list of files on the system having permissions different from what
# is expected by the RPM database
readarray -t FILES_WITH_INCORRECT_PERMS < <(rpm -Va --nofiledigest | awk '{ if (substr($0,2,1)=="M") print $NF }')

for FILE_PATH in "${FILES_WITH_INCORRECT_PERMS[@]}"
do
	RPM_PACKAGE=$(rpm -qf "$FILE_PATH")
	# Use an associative array to store packages as it's keys, not having to care about duplicates.
	SETPERMS_RPM_DICT["$RPM_PACKAGE"]=1
done

# For each of the RPM packages left in the list -- reset its permissions to the
# correct values
for RPM_PACKAGE in "${!SETPERMS_RPM_DICT[@]}"
do
	rpm --setperms "${RPM_PACKAGE}"
done

# END fix for 'xccdf_org.ssgproject.content_rule_rpm_verify_permissions'

###############################################################################
# BEGIN fix (24 / 114) for 'xccdf_org.ssgproject.content_rule_rpm_verify_ownership'
###############################################################################
(>&2 echo "Remediating rule 24/114: 'xccdf_org.ssgproject.content_rule_rpm_verify_ownership'")

# Declare array to hold set of RPM packages we need to correct permissions for
declare -A SETPERMS_RPM_DICT

# Create a list of files on the system having permissions different from what
# is expected by the RPM database
readarray -t FILES_WITH_INCORRECT_PERMS < <(rpm -Va --nofiledigest | awk '{ if (substr($0,6,1)=="U" || substr($0,7,1)=="G") print $NF }')

for FILE_PATH in "${FILES_WITH_INCORRECT_PERMS[@]}"
do
        RPM_PACKAGE=$(rpm -qf "$FILE_PATH")
	# Use an associative array to store packages as it's keys, not having to care about duplicates.
	SETPERMS_RPM_DICT["$RPM_PACKAGE"]=1
done

# For each of the RPM packages left in the list -- reset its permissions to the
# correct values
for RPM_PACKAGE in "${!SETPERMS_RPM_DICT[@]}"
do
        rpm --setugids "${RPM_PACKAGE}"
done

# END fix for 'xccdf_org.ssgproject.content_rule_rpm_verify_ownership'

###############################################################################
# BEGIN fix (25 / 114) for 'xccdf_org.ssgproject.content_rule_install_antivirus'
###############################################################################
(>&2 echo "Remediating rule 25/114: 'xccdf_org.ssgproject.content_rule_install_antivirus'")
(>&2 echo "FIX FOR THIS RULE 'xccdf_org.ssgproject.content_rule_install_antivirus' IS MISSING!")

# END fix for 'xccdf_org.ssgproject.content_rule_install_antivirus'

###############################################################################
# BEGIN fix (26 / 114) for 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'
###############################################################################
(>&2 echo "Remediating rule 26/114: 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'")
yum -y update

# END fix for 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'

###############################################################################
# BEGIN fix (27 / 114) for 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'
###############################################################################
(>&2 echo "Remediating rule 27/114: 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'")
yum -y update

# END fix for 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'

###############################################################################
# BEGIN fix (28 / 114) for 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'
###############################################################################
(>&2 echo "Remediating rule 28/114: 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'")
yum -y update

# END fix for 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'

###############################################################################
# BEGIN fix (29 / 114) for 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'
###############################################################################
(>&2 echo "Remediating rule 29/114: 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'")
yum -y update

# END fix for 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'

###############################################################################
# BEGIN fix (30 / 114) for 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'
###############################################################################
(>&2 echo "Remediating rule 30/114: 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'")
yum -y update

# END fix for 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'

###############################################################################
# BEGIN fix (31 / 114) for 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'
###############################################################################
(>&2 echo "Remediating rule 31/114: 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'")
yum -y update

# END fix for 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'

###############################################################################
# BEGIN fix (32 / 114) for 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'
###############################################################################
(>&2 echo "Remediating rule 32/114: 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'")
yum -y update

# END fix for 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'

###############################################################################
# BEGIN fix (33 / 114) for 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'
###############################################################################
(>&2 echo "Remediating rule 33/114: 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'")
yum -y update

# END fix for 'xccdf_org.ssgproject.content_rule_security_patches_up_to_date'

###############################################################################
# BEGIN fix (34 / 114) for 'xccdf_org.ssgproject.content_rule_rsyslog_files_permissions'
###############################################################################
(>&2 echo "Remediating rule 34/114: 'xccdf_org.ssgproject.content_rule_rsyslog_files_permissions'")

# List of log file paths to be inspected for correct permissions
# * Primarily inspect log file paths listed in /etc/rsyslog.conf
RSYSLOG_ETC_CONFIG="/etc/rsyslog.conf"
# * And also the log file paths listed after rsyslog's $IncludeConfig directive
#   (store the result into array for the case there's shell glob used as value of IncludeConfig)
readarray -t RSYSLOG_INCLUDE_CONFIG < <(grep -e "\$IncludeConfig[[:space:]]\+[^[:space:];]\+" /etc/rsyslog.conf | cut -d ' ' -f 2)
# Declare an array to hold the final list of different log file paths
declare -a LOG_FILE_PATHS

# Browse each file selected above as containing paths of log files
# ('/etc/rsyslog.conf' and '/etc/rsyslog.d/*.conf' in the default configuration)
for LOG_FILE in "${RSYSLOG_ETC_CONFIG}" "${RSYSLOG_INCLUDE_CONFIG[@]}"
do
	# From each of these files extract just particular log file path(s), thus:
	# * Ignore lines starting with space (' '), comment ('#"), or variable syntax ('$') characters,
	# * Ignore empty lines,
	# * Strip quotes and closing brackets from paths.
	# * Ignore paths that match /dev|/etc.*\.conf, as those are paths, but likely not log files
	# * From the remaining valid rows select only fields constituting a log file path
	# Text file column is understood to represent a log file path if and only if all of the following are met:
	# * it contains at least one slash '/' character,
	# * it is preceded by space
	# * it doesn't contain space (' '), colon (':'), and semicolon (';') characters
	# Search log file for path(s) only in case it exists!
	if [[ -f "${LOG_FILE}" ]]
	then
		NORMALIZED_CONFIG_FILE_LINES=$(sed -e "/^[[:space:]|#|$]/d" "${LOG_FILE}")
		LINES_WITH_PATHS=$(grep '[^/]*\s\+\S*/\S\+' <<< "${NORMALIZED_CONFIG_FILE_LINES}")
		FILTERED_PATHS=$(sed -e 's/[^\/]*[[:space:]]*\([^:;[:space:]]*\)/\1/g' <<< "${LINES_WITH_PATHS}")
		CLEANED_PATHS=$(sed -e "s/[\"')]//g; /\\/etc.*\.conf/d; /\\/dev\\//d" <<< "${FILTERED_PATHS}")
		MATCHED_ITEMS=$(sed -e "/^$/d" <<< "${CLEANED_PATHS}")
		# Since above sed command might return more than one item (delimited by newline), split the particular
		# matches entries into new array specific for this log file
		readarray -t ARRAY_FOR_LOG_FILE <<< "$MATCHED_ITEMS"
		# Concatenate the two arrays - previous content of $LOG_FILE_PATHS array with
		# items from newly created array for this log file
		LOG_FILE_PATHS+=("${ARRAY_FOR_LOG_FILE[@]}")
		# Delete the temporary array
		unset ARRAY_FOR_LOG_FILE
	fi
done

for LOG_FILE_PATH in "${LOG_FILE_PATHS[@]}"
do
	# Sanity check - if particular $LOG_FILE_PATH is empty string, skip it from further processing
	if [ -z "$LOG_FILE_PATH" ]
	then
		continue
	fi

	
	# Per https://access.redhat.com/solutions/66805 '/var/log/boot.log' log file needs special care => perform it
	# This has been fixed in RHEL7, the workaround is only necessary for RHEL6
	if [ "$LOG_FILE_PATH" == "/var/log/boot.log" ]
	then
		# Ensure permissions of /var/log/boot.log are configured to be updated in /etc/rc.local
		if ! /bin/grep -q "boot.log" "/etc/rc.local"
		then
			echo "/bin/chmod 600 /var/log/boot.log" >> /etc/rc.local
		fi
		# Ensure /etc/rc.d/rc.local has user-executable permission
		# (in order to be actually executed during boot)
		if [ "$(/usr/bin/stat -c %a /etc/rc.d/rc.local)" -ne 744 ]
		then
			/bin/chmod u+x /etc/rc.d/rc.local
		fi
	fi
	

	# Also for each log file check if its permissions differ from 600. If so, correct them
	if [ -f "$LOG_FILE_PATH" ] && [ "$(/usr/bin/stat -c %a "$LOG_FILE_PATH")" -ne 600 ]
	then
		/bin/chmod 600 "$LOG_FILE_PATH"
	fi
done

# END fix for 'xccdf_org.ssgproject.content_rule_rsyslog_files_permissions'

###############################################################################
# BEGIN fix (35 / 114) for 'xccdf_org.ssgproject.content_rule_rsyslog_remote_loghost'
###############################################################################
(>&2 echo "Remediating rule 35/114: 'xccdf_org.ssgproject.content_rule_rsyslog_remote_loghost'")

rsyslog_remote_loghost_address="logcollector"
# Function to replace configuration setting in config file or add the configuration setting if
# it does not exist.
#
# Expects arguments:
#
# config_file:		Configuration file that will be modified
# key:			Configuration option to change
# value:		Value of the configuration option to change
# cce:			The CCE identifier or '@CCENUM@' if no CCE identifier exists
# format:		The printf-like format string that will be given stripped key and value as arguments,
#			so e.g. '%s=%s' will result in key=value subsitution (i.e. without spaces around =)
#
# Optional arugments:
#
# format:		Optional argument to specify the format of how key/value should be
# 			modified/appended in the configuration file. The default is key = value.
#
# Example Call(s):
#
#     With default format of 'key = value':
#     replace_or_append '/etc/sysctl.conf' '^kernel.randomize_va_space' '2' '@CCENUM@'
#
#     With custom key/value format:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' 'disabled' '@CCENUM@' '%s=%s'
#
#     With a variable:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' $var_selinux_state '@CCENUM@' '%s=%s'
#
function replace_or_append {
  local default_format='%s = %s' case_insensitive_mode=yes sed_case_insensitive_option='' grep_case_insensitive_option=''
  local config_file=$1
  local key=$2
  local value=$3
  local cce=$4
  local format=$5

  if [ "$case_insensitive_mode" = yes ]; then
    sed_case_insensitive_option="i"
    grep_case_insensitive_option="-i"
  fi
  [ -n "$format" ] || format="$default_format"
  # Check sanity of the input
  [ $# -ge "3" ] || { echo "Usage: replace_or_append <config_file_location> <key_to_search> <new_value> [<CCE number or literal '@CCENUM@' if unknown>] [printf-like format, default is '$default_format']" >&2; exit 1; }

  # Test if the config_file is a symbolic link. If so, use --follow-symlinks with sed.
  # Otherwise, regular sed command will do.
  sed_command=('sed' '-i')
  if test -L "$config_file"; then
    sed_command+=('--follow-symlinks')
  fi

  # Test that the cce arg is not empty or does not equal @CCENUM@.
  # If @CCENUM@ exists, it means that there is no CCE assigned.
  if [ -n "$cce" ] && [ "$cce" != '@CCENUM@' ]; then
    cce="${cce}"
  else
    cce="CCE"
  fi

  # Strip any search characters in the key arg so that the key can be replaced without
  # adding any search characters to the config file.
  stripped_key=$(sed 's/[\^=\$,;+]*//g' <<< "$key")

  # shellcheck disable=SC2059
  printf -v formatted_output "$format" "$stripped_key" "$value"

  # If the key exists, change it. Otherwise, add it to the config_file.
  # We search for the key string followed by a word boundary (matched by \>),
  # so if we search for 'setting', 'setting2' won't match.
  if LC_ALL=C grep -q -m 1 $grep_case_insensitive_option -e "${key}\\>" "$config_file"; then
    "${sed_command[@]}" "s/${key}\\>.*/$formatted_output/g$sed_case_insensitive_option" "$config_file"
  else
    # \n is precaution for case where file ends without trailing newline
    printf '\n# Per %s: Set %s in %s\n' "$cce" "$formatted_output" "$config_file" >> "$config_file"
    printf '%s\n' "$formatted_output" >> "$config_file"
  fi
}
replace_or_append '/etc/rsyslog.conf' '^\*\.\*' "@@$rsyslog_remote_loghost_address" 'CCE-26801-1' '%s %s'

# END fix for 'xccdf_org.ssgproject.content_rule_rsyslog_remote_loghost'

###############################################################################
# BEGIN fix (36 / 114) for 'xccdf_org.ssgproject.content_rule_ensure_logrotate_activated'
###############################################################################
(>&2 echo "Remediating rule 36/114: 'xccdf_org.ssgproject.content_rule_ensure_logrotate_activated'")

LOGROTATE_CONF_FILE="/etc/logrotate.conf"
CRON_DAILY_LOGROTATE_FILE="/etc/cron.daily/logrotate"

# daily rotation is configured
grep -q "^daily$" $LOGROTATE_CONF_FILE|| echo "daily" >> $LOGROTATE_CONF_FILE

# remove any line configuring weekly, monthly or yearly rotation
sed -i -r "/^(weekly|monthly|yearly)$/d" $LOGROTATE_CONF_FILE

# configure cron.daily if not already
if ! grep -q "^[[:space:]]*/usr/sbin/logrotate[[:alnum:][:blank:][:punct:]]*$LOGROTATE_CONF_FILE$" $CRON_DAILY_LOGROTATE_FILE; then
	echo "#!/bin/sh" > $CRON_DAILY_LOGROTATE_FILE
	echo "/usr/sbin/logrotate $LOGROTATE_CONF_FILE" >> $CRON_DAILY_LOGROTATE_FILE
fi

# END fix for 'xccdf_org.ssgproject.content_rule_ensure_logrotate_activated'

###############################################################################
# BEGIN fix (37 / 114) for 'xccdf_org.ssgproject.content_rule_service_bluetooth_disabled'
###############################################################################
(>&2 echo "Remediating rule 37/114: 'xccdf_org.ssgproject.content_rule_service_bluetooth_disabled'")

/sbin/service 'bluetooth' stop
/sbin/chkconfig --level 0123456 'bluetooth' off

# END fix for 'xccdf_org.ssgproject.content_rule_service_bluetooth_disabled'

###############################################################################
# BEGIN fix (38 / 114) for 'xccdf_org.ssgproject.content_rule_kernel_module_bluetooth_disabled'
###############################################################################
(>&2 echo "Remediating rule 38/114: 'xccdf_org.ssgproject.content_rule_kernel_module_bluetooth_disabled'")
if LC_ALL=C grep -q -m 1 "^install bluetooth" /etc/modprobe.d/bluetooth.conf ; then
	sed -i 's/^install bluetooth.*/install bluetooth /bin/true/g' /etc/modprobe.d/bluetooth.conf
else
	echo -e "\n# Disable per security requirements" >> /etc/modprobe.d/bluetooth.conf
	echo "install bluetooth /bin/true" >> /etc/modprobe.d/bluetooth.conf
fi

# END fix for 'xccdf_org.ssgproject.content_rule_kernel_module_bluetooth_disabled'

###############################################################################
# BEGIN fix (39 / 114) for 'xccdf_org.ssgproject.content_rule_package_libreswan_installed'
###############################################################################
(>&2 echo "Remediating rule 39/114: 'xccdf_org.ssgproject.content_rule_package_libreswan_installed'")

if ! rpm -q --quiet "libreswan" ; then
    yum install -y "libreswan"
fi

# END fix for 'xccdf_org.ssgproject.content_rule_package_libreswan_installed'

###############################################################################
# BEGIN fix (40 / 114) for 'xccdf_org.ssgproject.content_rule_set_ip6tables_default_rule'
###############################################################################
(>&2 echo "Remediating rule 40/114: 'xccdf_org.ssgproject.content_rule_set_ip6tables_default_rule'")
sed -i 's/^:INPUT ACCEPT.*/:INPUT DROP [0:0]/g' /etc/sysconfig/ip6tables

# END fix for 'xccdf_org.ssgproject.content_rule_set_ip6tables_default_rule'

###############################################################################
# BEGIN fix (41 / 114) for 'xccdf_org.ssgproject.content_rule_set_iptables_default_rule'
###############################################################################
(>&2 echo "Remediating rule 41/114: 'xccdf_org.ssgproject.content_rule_set_iptables_default_rule'")
sed -i 's/^:INPUT ACCEPT.*/:INPUT DROP [0:0]/g' /etc/sysconfig/iptables

# END fix for 'xccdf_org.ssgproject.content_rule_set_iptables_default_rule'

###############################################################################
# BEGIN fix (42 / 114) for 'xccdf_org.ssgproject.content_rule_set_iptables_default_rule_forward'
###############################################################################
(>&2 echo "Remediating rule 42/114: 'xccdf_org.ssgproject.content_rule_set_iptables_default_rule_forward'")
sed -i 's/^:FORWARD ACCEPT.*/:FORWARD DROP [0:0]/g' /etc/sysconfig/iptables

# END fix for 'xccdf_org.ssgproject.content_rule_set_iptables_default_rule_forward'

###############################################################################
# BEGIN fix (43 / 114) for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_icmp_echo_ignore_broadcasts'
###############################################################################
(>&2 echo "Remediating rule 43/114: 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_icmp_echo_ignore_broadcasts'")

sysctl_net_ipv4_icmp_echo_ignore_broadcasts_value="1"

#
# Set runtime for net.ipv4.icmp_echo_ignore_broadcasts
#
/sbin/sysctl -q -n -w net.ipv4.icmp_echo_ignore_broadcasts="$sysctl_net_ipv4_icmp_echo_ignore_broadcasts_value"

#
# If net.ipv4.icmp_echo_ignore_broadcasts present in /etc/sysctl.conf, change value to appropriate value
#	else, add "net.ipv4.icmp_echo_ignore_broadcasts = value" to /etc/sysctl.conf
#
# Function to replace configuration setting in config file or add the configuration setting if
# it does not exist.
#
# Expects arguments:
#
# config_file:		Configuration file that will be modified
# key:			Configuration option to change
# value:		Value of the configuration option to change
# cce:			The CCE identifier or '@CCENUM@' if no CCE identifier exists
# format:		The printf-like format string that will be given stripped key and value as arguments,
#			so e.g. '%s=%s' will result in key=value subsitution (i.e. without spaces around =)
#
# Optional arugments:
#
# format:		Optional argument to specify the format of how key/value should be
# 			modified/appended in the configuration file. The default is key = value.
#
# Example Call(s):
#
#     With default format of 'key = value':
#     replace_or_append '/etc/sysctl.conf' '^kernel.randomize_va_space' '2' '@CCENUM@'
#
#     With custom key/value format:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' 'disabled' '@CCENUM@' '%s=%s'
#
#     With a variable:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' $var_selinux_state '@CCENUM@' '%s=%s'
#
function replace_or_append {
  local default_format='%s = %s' case_insensitive_mode=yes sed_case_insensitive_option='' grep_case_insensitive_option=''
  local config_file=$1
  local key=$2
  local value=$3
  local cce=$4
  local format=$5

  if [ "$case_insensitive_mode" = yes ]; then
    sed_case_insensitive_option="i"
    grep_case_insensitive_option="-i"
  fi
  [ -n "$format" ] || format="$default_format"
  # Check sanity of the input
  [ $# -ge "3" ] || { echo "Usage: replace_or_append <config_file_location> <key_to_search> <new_value> [<CCE number or literal '@CCENUM@' if unknown>] [printf-like format, default is '$default_format']" >&2; exit 1; }

  # Test if the config_file is a symbolic link. If so, use --follow-symlinks with sed.
  # Otherwise, regular sed command will do.
  sed_command=('sed' '-i')
  if test -L "$config_file"; then
    sed_command+=('--follow-symlinks')
  fi

  # Test that the cce arg is not empty or does not equal @CCENUM@.
  # If @CCENUM@ exists, it means that there is no CCE assigned.
  if [ -n "$cce" ] && [ "$cce" != '@CCENUM@' ]; then
    cce="${cce}"
  else
    cce="CCE"
  fi

  # Strip any search characters in the key arg so that the key can be replaced without
  # adding any search characters to the config file.
  stripped_key=$(sed 's/[\^=\$,;+]*//g' <<< "$key")

  # shellcheck disable=SC2059
  printf -v formatted_output "$format" "$stripped_key" "$value"

  # If the key exists, change it. Otherwise, add it to the config_file.
  # We search for the key string followed by a word boundary (matched by \>),
  # so if we search for 'setting', 'setting2' won't match.
  if LC_ALL=C grep -q -m 1 $grep_case_insensitive_option -e "${key}\\>" "$config_file"; then
    "${sed_command[@]}" "s/${key}\\>.*/$formatted_output/g$sed_case_insensitive_option" "$config_file"
  else
    # \n is precaution for case where file ends without trailing newline
    printf '\n# Per %s: Set %s in %s\n' "$cce" "$formatted_output" "$config_file" >> "$config_file"
    printf '%s\n' "$formatted_output" >> "$config_file"
  fi
}
replace_or_append '/etc/sysctl.conf' '^net.ipv4.icmp_echo_ignore_broadcasts' "$sysctl_net_ipv4_icmp_echo_ignore_broadcasts_value" 'CCE-26883-9'

# END fix for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_icmp_echo_ignore_broadcasts'

###############################################################################
# BEGIN fix (44 / 114) for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_all_secure_redirects'
###############################################################################
(>&2 echo "Remediating rule 44/114: 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_all_secure_redirects'")

sysctl_net_ipv4_conf_all_secure_redirects_value="0"

#
# Set runtime for net.ipv4.conf.all.secure_redirects
#
/sbin/sysctl -q -n -w net.ipv4.conf.all.secure_redirects="$sysctl_net_ipv4_conf_all_secure_redirects_value"

#
# If net.ipv4.conf.all.secure_redirects present in /etc/sysctl.conf, change value to appropriate value
#	else, add "net.ipv4.conf.all.secure_redirects = value" to /etc/sysctl.conf
#
# Function to replace configuration setting in config file or add the configuration setting if
# it does not exist.
#
# Expects arguments:
#
# config_file:		Configuration file that will be modified
# key:			Configuration option to change
# value:		Value of the configuration option to change
# cce:			The CCE identifier or '@CCENUM@' if no CCE identifier exists
# format:		The printf-like format string that will be given stripped key and value as arguments,
#			so e.g. '%s=%s' will result in key=value subsitution (i.e. without spaces around =)
#
# Optional arugments:
#
# format:		Optional argument to specify the format of how key/value should be
# 			modified/appended in the configuration file. The default is key = value.
#
# Example Call(s):
#
#     With default format of 'key = value':
#     replace_or_append '/etc/sysctl.conf' '^kernel.randomize_va_space' '2' '@CCENUM@'
#
#     With custom key/value format:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' 'disabled' '@CCENUM@' '%s=%s'
#
#     With a variable:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' $var_selinux_state '@CCENUM@' '%s=%s'
#
function replace_or_append {
  local default_format='%s = %s' case_insensitive_mode=yes sed_case_insensitive_option='' grep_case_insensitive_option=''
  local config_file=$1
  local key=$2
  local value=$3
  local cce=$4
  local format=$5

  if [ "$case_insensitive_mode" = yes ]; then
    sed_case_insensitive_option="i"
    grep_case_insensitive_option="-i"
  fi
  [ -n "$format" ] || format="$default_format"
  # Check sanity of the input
  [ $# -ge "3" ] || { echo "Usage: replace_or_append <config_file_location> <key_to_search> <new_value> [<CCE number or literal '@CCENUM@' if unknown>] [printf-like format, default is '$default_format']" >&2; exit 1; }

  # Test if the config_file is a symbolic link. If so, use --follow-symlinks with sed.
  # Otherwise, regular sed command will do.
  sed_command=('sed' '-i')
  if test -L "$config_file"; then
    sed_command+=('--follow-symlinks')
  fi

  # Test that the cce arg is not empty or does not equal @CCENUM@.
  # If @CCENUM@ exists, it means that there is no CCE assigned.
  if [ -n "$cce" ] && [ "$cce" != '@CCENUM@' ]; then
    cce="${cce}"
  else
    cce="CCE"
  fi

  # Strip any search characters in the key arg so that the key can be replaced without
  # adding any search characters to the config file.
  stripped_key=$(sed 's/[\^=\$,;+]*//g' <<< "$key")

  # shellcheck disable=SC2059
  printf -v formatted_output "$format" "$stripped_key" "$value"

  # If the key exists, change it. Otherwise, add it to the config_file.
  # We search for the key string followed by a word boundary (matched by \>),
  # so if we search for 'setting', 'setting2' won't match.
  if LC_ALL=C grep -q -m 1 $grep_case_insensitive_option -e "${key}\\>" "$config_file"; then
    "${sed_command[@]}" "s/${key}\\>.*/$formatted_output/g$sed_case_insensitive_option" "$config_file"
  else
    # \n is precaution for case where file ends without trailing newline
    printf '\n# Per %s: Set %s in %s\n' "$cce" "$formatted_output" "$config_file" >> "$config_file"
    printf '%s\n' "$formatted_output" >> "$config_file"
  fi
}
replace_or_append '/etc/sysctl.conf' '^net.ipv4.conf.all.secure_redirects' "$sysctl_net_ipv4_conf_all_secure_redirects_value" 'CCE-26854-0'

# END fix for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_all_secure_redirects'

###############################################################################
# BEGIN fix (45 / 114) for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_all_accept_redirects'
###############################################################################
(>&2 echo "Remediating rule 45/114: 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_all_accept_redirects'")

sysctl_net_ipv4_conf_all_accept_redirects_value="0"

#
# Set runtime for net.ipv4.conf.all.accept_redirects
#
/sbin/sysctl -q -n -w net.ipv4.conf.all.accept_redirects="$sysctl_net_ipv4_conf_all_accept_redirects_value"

#
# If net.ipv4.conf.all.accept_redirects present in /etc/sysctl.conf, change value to appropriate value
#	else, add "net.ipv4.conf.all.accept_redirects = value" to /etc/sysctl.conf
#
# Function to replace configuration setting in config file or add the configuration setting if
# it does not exist.
#
# Expects arguments:
#
# config_file:		Configuration file that will be modified
# key:			Configuration option to change
# value:		Value of the configuration option to change
# cce:			The CCE identifier or '@CCENUM@' if no CCE identifier exists
# format:		The printf-like format string that will be given stripped key and value as arguments,
#			so e.g. '%s=%s' will result in key=value subsitution (i.e. without spaces around =)
#
# Optional arugments:
#
# format:		Optional argument to specify the format of how key/value should be
# 			modified/appended in the configuration file. The default is key = value.
#
# Example Call(s):
#
#     With default format of 'key = value':
#     replace_or_append '/etc/sysctl.conf' '^kernel.randomize_va_space' '2' '@CCENUM@'
#
#     With custom key/value format:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' 'disabled' '@CCENUM@' '%s=%s'
#
#     With a variable:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' $var_selinux_state '@CCENUM@' '%s=%s'
#
function replace_or_append {
  local default_format='%s = %s' case_insensitive_mode=yes sed_case_insensitive_option='' grep_case_insensitive_option=''
  local config_file=$1
  local key=$2
  local value=$3
  local cce=$4
  local format=$5

  if [ "$case_insensitive_mode" = yes ]; then
    sed_case_insensitive_option="i"
    grep_case_insensitive_option="-i"
  fi
  [ -n "$format" ] || format="$default_format"
  # Check sanity of the input
  [ $# -ge "3" ] || { echo "Usage: replace_or_append <config_file_location> <key_to_search> <new_value> [<CCE number or literal '@CCENUM@' if unknown>] [printf-like format, default is '$default_format']" >&2; exit 1; }

  # Test if the config_file is a symbolic link. If so, use --follow-symlinks with sed.
  # Otherwise, regular sed command will do.
  sed_command=('sed' '-i')
  if test -L "$config_file"; then
    sed_command+=('--follow-symlinks')
  fi

  # Test that the cce arg is not empty or does not equal @CCENUM@.
  # If @CCENUM@ exists, it means that there is no CCE assigned.
  if [ -n "$cce" ] && [ "$cce" != '@CCENUM@' ]; then
    cce="${cce}"
  else
    cce="CCE"
  fi

  # Strip any search characters in the key arg so that the key can be replaced without
  # adding any search characters to the config file.
  stripped_key=$(sed 's/[\^=\$,;+]*//g' <<< "$key")

  # shellcheck disable=SC2059
  printf -v formatted_output "$format" "$stripped_key" "$value"

  # If the key exists, change it. Otherwise, add it to the config_file.
  # We search for the key string followed by a word boundary (matched by \>),
  # so if we search for 'setting', 'setting2' won't match.
  if LC_ALL=C grep -q -m 1 $grep_case_insensitive_option -e "${key}\\>" "$config_file"; then
    "${sed_command[@]}" "s/${key}\\>.*/$formatted_output/g$sed_case_insensitive_option" "$config_file"
  else
    # \n is precaution for case where file ends without trailing newline
    printf '\n# Per %s: Set %s in %s\n' "$cce" "$formatted_output" "$config_file" >> "$config_file"
    printf '%s\n' "$formatted_output" >> "$config_file"
  fi
}
replace_or_append '/etc/sysctl.conf' '^net.ipv4.conf.all.accept_redirects' "$sysctl_net_ipv4_conf_all_accept_redirects_value" 'CCE-27027-2'

# END fix for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_all_accept_redirects'

###############################################################################
# BEGIN fix (46 / 114) for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_default_secure_redirects'
###############################################################################
(>&2 echo "Remediating rule 46/114: 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_default_secure_redirects'")

sysctl_net_ipv4_conf_default_secure_redirects_value="0"

#
# Set runtime for net.ipv4.conf.default.secure_redirects
#
/sbin/sysctl -q -n -w net.ipv4.conf.default.secure_redirects="$sysctl_net_ipv4_conf_default_secure_redirects_value"

#
# If net.ipv4.conf.default.secure_redirects present in /etc/sysctl.conf, change value to appropriate value
#	else, add "net.ipv4.conf.default.secure_redirects = value" to /etc/sysctl.conf
#
# Function to replace configuration setting in config file or add the configuration setting if
# it does not exist.
#
# Expects arguments:
#
# config_file:		Configuration file that will be modified
# key:			Configuration option to change
# value:		Value of the configuration option to change
# cce:			The CCE identifier or '@CCENUM@' if no CCE identifier exists
# format:		The printf-like format string that will be given stripped key and value as arguments,
#			so e.g. '%s=%s' will result in key=value subsitution (i.e. without spaces around =)
#
# Optional arugments:
#
# format:		Optional argument to specify the format of how key/value should be
# 			modified/appended in the configuration file. The default is key = value.
#
# Example Call(s):
#
#     With default format of 'key = value':
#     replace_or_append '/etc/sysctl.conf' '^kernel.randomize_va_space' '2' '@CCENUM@'
#
#     With custom key/value format:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' 'disabled' '@CCENUM@' '%s=%s'
#
#     With a variable:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' $var_selinux_state '@CCENUM@' '%s=%s'
#
function replace_or_append {
  local default_format='%s = %s' case_insensitive_mode=yes sed_case_insensitive_option='' grep_case_insensitive_option=''
  local config_file=$1
  local key=$2
  local value=$3
  local cce=$4
  local format=$5

  if [ "$case_insensitive_mode" = yes ]; then
    sed_case_insensitive_option="i"
    grep_case_insensitive_option="-i"
  fi
  [ -n "$format" ] || format="$default_format"
  # Check sanity of the input
  [ $# -ge "3" ] || { echo "Usage: replace_or_append <config_file_location> <key_to_search> <new_value> [<CCE number or literal '@CCENUM@' if unknown>] [printf-like format, default is '$default_format']" >&2; exit 1; }

  # Test if the config_file is a symbolic link. If so, use --follow-symlinks with sed.
  # Otherwise, regular sed command will do.
  sed_command=('sed' '-i')
  if test -L "$config_file"; then
    sed_command+=('--follow-symlinks')
  fi

  # Test that the cce arg is not empty or does not equal @CCENUM@.
  # If @CCENUM@ exists, it means that there is no CCE assigned.
  if [ -n "$cce" ] && [ "$cce" != '@CCENUM@' ]; then
    cce="${cce}"
  else
    cce="CCE"
  fi

  # Strip any search characters in the key arg so that the key can be replaced without
  # adding any search characters to the config file.
  stripped_key=$(sed 's/[\^=\$,;+]*//g' <<< "$key")

  # shellcheck disable=SC2059
  printf -v formatted_output "$format" "$stripped_key" "$value"

  # If the key exists, change it. Otherwise, add it to the config_file.
  # We search for the key string followed by a word boundary (matched by \>),
  # so if we search for 'setting', 'setting2' won't match.
  if LC_ALL=C grep -q -m 1 $grep_case_insensitive_option -e "${key}\\>" "$config_file"; then
    "${sed_command[@]}" "s/${key}\\>.*/$formatted_output/g$sed_case_insensitive_option" "$config_file"
  else
    # \n is precaution for case where file ends without trailing newline
    printf '\n# Per %s: Set %s in %s\n' "$cce" "$formatted_output" "$config_file" >> "$config_file"
    printf '%s\n' "$formatted_output" >> "$config_file"
  fi
}
replace_or_append '/etc/sysctl.conf' '^net.ipv4.conf.default.secure_redirects' "$sysctl_net_ipv4_conf_default_secure_redirects_value" 'CCE-26831-8'

# END fix for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_default_secure_redirects'

###############################################################################
# BEGIN fix (47 / 114) for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_icmp_ignore_bogus_error_responses'
###############################################################################
(>&2 echo "Remediating rule 47/114: 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_icmp_ignore_bogus_error_responses'")

sysctl_net_ipv4_icmp_ignore_bogus_error_responses_value="1"

#
# Set runtime for net.ipv4.icmp_ignore_bogus_error_responses
#
/sbin/sysctl -q -n -w net.ipv4.icmp_ignore_bogus_error_responses="$sysctl_net_ipv4_icmp_ignore_bogus_error_responses_value"

#
# If net.ipv4.icmp_ignore_bogus_error_responses present in /etc/sysctl.conf, change value to appropriate value
#	else, add "net.ipv4.icmp_ignore_bogus_error_responses = value" to /etc/sysctl.conf
#
# Function to replace configuration setting in config file or add the configuration setting if
# it does not exist.
#
# Expects arguments:
#
# config_file:		Configuration file that will be modified
# key:			Configuration option to change
# value:		Value of the configuration option to change
# cce:			The CCE identifier or '@CCENUM@' if no CCE identifier exists
# format:		The printf-like format string that will be given stripped key and value as arguments,
#			so e.g. '%s=%s' will result in key=value subsitution (i.e. without spaces around =)
#
# Optional arugments:
#
# format:		Optional argument to specify the format of how key/value should be
# 			modified/appended in the configuration file. The default is key = value.
#
# Example Call(s):
#
#     With default format of 'key = value':
#     replace_or_append '/etc/sysctl.conf' '^kernel.randomize_va_space' '2' '@CCENUM@'
#
#     With custom key/value format:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' 'disabled' '@CCENUM@' '%s=%s'
#
#     With a variable:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' $var_selinux_state '@CCENUM@' '%s=%s'
#
function replace_or_append {
  local default_format='%s = %s' case_insensitive_mode=yes sed_case_insensitive_option='' grep_case_insensitive_option=''
  local config_file=$1
  local key=$2
  local value=$3
  local cce=$4
  local format=$5

  if [ "$case_insensitive_mode" = yes ]; then
    sed_case_insensitive_option="i"
    grep_case_insensitive_option="-i"
  fi
  [ -n "$format" ] || format="$default_format"
  # Check sanity of the input
  [ $# -ge "3" ] || { echo "Usage: replace_or_append <config_file_location> <key_to_search> <new_value> [<CCE number or literal '@CCENUM@' if unknown>] [printf-like format, default is '$default_format']" >&2; exit 1; }

  # Test if the config_file is a symbolic link. If so, use --follow-symlinks with sed.
  # Otherwise, regular sed command will do.
  sed_command=('sed' '-i')
  if test -L "$config_file"; then
    sed_command+=('--follow-symlinks')
  fi

  # Test that the cce arg is not empty or does not equal @CCENUM@.
  # If @CCENUM@ exists, it means that there is no CCE assigned.
  if [ -n "$cce" ] && [ "$cce" != '@CCENUM@' ]; then
    cce="${cce}"
  else
    cce="CCE"
  fi

  # Strip any search characters in the key arg so that the key can be replaced without
  # adding any search characters to the config file.
  stripped_key=$(sed 's/[\^=\$,;+]*//g' <<< "$key")

  # shellcheck disable=SC2059
  printf -v formatted_output "$format" "$stripped_key" "$value"

  # If the key exists, change it. Otherwise, add it to the config_file.
  # We search for the key string followed by a word boundary (matched by \>),
  # so if we search for 'setting', 'setting2' won't match.
  if LC_ALL=C grep -q -m 1 $grep_case_insensitive_option -e "${key}\\>" "$config_file"; then
    "${sed_command[@]}" "s/${key}\\>.*/$formatted_output/g$sed_case_insensitive_option" "$config_file"
  else
    # \n is precaution for case where file ends without trailing newline
    printf '\n# Per %s: Set %s in %s\n' "$cce" "$formatted_output" "$config_file" >> "$config_file"
    printf '%s\n' "$formatted_output" >> "$config_file"
  fi
}
replace_or_append '/etc/sysctl.conf' '^net.ipv4.icmp_ignore_bogus_error_responses' "$sysctl_net_ipv4_icmp_ignore_bogus_error_responses_value" 'CCE-26993-6'

# END fix for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_icmp_ignore_bogus_error_responses'

###############################################################################
# BEGIN fix (48 / 114) for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_all_log_martians'
###############################################################################
(>&2 echo "Remediating rule 48/114: 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_all_log_martians'")

sysctl_net_ipv4_conf_all_log_martians_value="1"

#
# Set runtime for net.ipv4.conf.all.log_martians
#
/sbin/sysctl -q -n -w net.ipv4.conf.all.log_martians="$sysctl_net_ipv4_conf_all_log_martians_value"

#
# If net.ipv4.conf.all.log_martians present in /etc/sysctl.conf, change value to appropriate value
#	else, add "net.ipv4.conf.all.log_martians = value" to /etc/sysctl.conf
#
# Function to replace configuration setting in config file or add the configuration setting if
# it does not exist.
#
# Expects arguments:
#
# config_file:		Configuration file that will be modified
# key:			Configuration option to change
# value:		Value of the configuration option to change
# cce:			The CCE identifier or '@CCENUM@' if no CCE identifier exists
# format:		The printf-like format string that will be given stripped key and value as arguments,
#			so e.g. '%s=%s' will result in key=value subsitution (i.e. without spaces around =)
#
# Optional arugments:
#
# format:		Optional argument to specify the format of how key/value should be
# 			modified/appended in the configuration file. The default is key = value.
#
# Example Call(s):
#
#     With default format of 'key = value':
#     replace_or_append '/etc/sysctl.conf' '^kernel.randomize_va_space' '2' '@CCENUM@'
#
#     With custom key/value format:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' 'disabled' '@CCENUM@' '%s=%s'
#
#     With a variable:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' $var_selinux_state '@CCENUM@' '%s=%s'
#
function replace_or_append {
  local default_format='%s = %s' case_insensitive_mode=yes sed_case_insensitive_option='' grep_case_insensitive_option=''
  local config_file=$1
  local key=$2
  local value=$3
  local cce=$4
  local format=$5

  if [ "$case_insensitive_mode" = yes ]; then
    sed_case_insensitive_option="i"
    grep_case_insensitive_option="-i"
  fi
  [ -n "$format" ] || format="$default_format"
  # Check sanity of the input
  [ $# -ge "3" ] || { echo "Usage: replace_or_append <config_file_location> <key_to_search> <new_value> [<CCE number or literal '@CCENUM@' if unknown>] [printf-like format, default is '$default_format']" >&2; exit 1; }

  # Test if the config_file is a symbolic link. If so, use --follow-symlinks with sed.
  # Otherwise, regular sed command will do.
  sed_command=('sed' '-i')
  if test -L "$config_file"; then
    sed_command+=('--follow-symlinks')
  fi

  # Test that the cce arg is not empty or does not equal @CCENUM@.
  # If @CCENUM@ exists, it means that there is no CCE assigned.
  if [ -n "$cce" ] && [ "$cce" != '@CCENUM@' ]; then
    cce="${cce}"
  else
    cce="CCE"
  fi

  # Strip any search characters in the key arg so that the key can be replaced without
  # adding any search characters to the config file.
  stripped_key=$(sed 's/[\^=\$,;+]*//g' <<< "$key")

  # shellcheck disable=SC2059
  printf -v formatted_output "$format" "$stripped_key" "$value"

  # If the key exists, change it. Otherwise, add it to the config_file.
  # We search for the key string followed by a word boundary (matched by \>),
  # so if we search for 'setting', 'setting2' won't match.
  if LC_ALL=C grep -q -m 1 $grep_case_insensitive_option -e "${key}\\>" "$config_file"; then
    "${sed_command[@]}" "s/${key}\\>.*/$formatted_output/g$sed_case_insensitive_option" "$config_file"
  else
    # \n is precaution for case where file ends without trailing newline
    printf '\n# Per %s: Set %s in %s\n' "$cce" "$formatted_output" "$config_file" >> "$config_file"
    printf '%s\n' "$formatted_output" >> "$config_file"
  fi
}
replace_or_append '/etc/sysctl.conf' '^net.ipv4.conf.all.log_martians' "$sysctl_net_ipv4_conf_all_log_martians_value" 'CCE-27066-0'

# END fix for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_all_log_martians'

###############################################################################
# BEGIN fix (49 / 114) for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_all_accept_source_route'
###############################################################################
(>&2 echo "Remediating rule 49/114: 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_all_accept_source_route'")

sysctl_net_ipv4_conf_all_accept_source_route_value="0"

#
# Set runtime for net.ipv4.conf.all.accept_source_route
#
/sbin/sysctl -q -n -w net.ipv4.conf.all.accept_source_route="$sysctl_net_ipv4_conf_all_accept_source_route_value"

#
# If net.ipv4.conf.all.accept_source_route present in /etc/sysctl.conf, change value to appropriate value
#	else, add "net.ipv4.conf.all.accept_source_route = value" to /etc/sysctl.conf
#
# Function to replace configuration setting in config file or add the configuration setting if
# it does not exist.
#
# Expects arguments:
#
# config_file:		Configuration file that will be modified
# key:			Configuration option to change
# value:		Value of the configuration option to change
# cce:			The CCE identifier or '@CCENUM@' if no CCE identifier exists
# format:		The printf-like format string that will be given stripped key and value as arguments,
#			so e.g. '%s=%s' will result in key=value subsitution (i.e. without spaces around =)
#
# Optional arugments:
#
# format:		Optional argument to specify the format of how key/value should be
# 			modified/appended in the configuration file. The default is key = value.
#
# Example Call(s):
#
#     With default format of 'key = value':
#     replace_or_append '/etc/sysctl.conf' '^kernel.randomize_va_space' '2' '@CCENUM@'
#
#     With custom key/value format:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' 'disabled' '@CCENUM@' '%s=%s'
#
#     With a variable:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' $var_selinux_state '@CCENUM@' '%s=%s'
#
function replace_or_append {
  local default_format='%s = %s' case_insensitive_mode=yes sed_case_insensitive_option='' grep_case_insensitive_option=''
  local config_file=$1
  local key=$2
  local value=$3
  local cce=$4
  local format=$5

  if [ "$case_insensitive_mode" = yes ]; then
    sed_case_insensitive_option="i"
    grep_case_insensitive_option="-i"
  fi
  [ -n "$format" ] || format="$default_format"
  # Check sanity of the input
  [ $# -ge "3" ] || { echo "Usage: replace_or_append <config_file_location> <key_to_search> <new_value> [<CCE number or literal '@CCENUM@' if unknown>] [printf-like format, default is '$default_format']" >&2; exit 1; }

  # Test if the config_file is a symbolic link. If so, use --follow-symlinks with sed.
  # Otherwise, regular sed command will do.
  sed_command=('sed' '-i')
  if test -L "$config_file"; then
    sed_command+=('--follow-symlinks')
  fi

  # Test that the cce arg is not empty or does not equal @CCENUM@.
  # If @CCENUM@ exists, it means that there is no CCE assigned.
  if [ -n "$cce" ] && [ "$cce" != '@CCENUM@' ]; then
    cce="${cce}"
  else
    cce="CCE"
  fi

  # Strip any search characters in the key arg so that the key can be replaced without
  # adding any search characters to the config file.
  stripped_key=$(sed 's/[\^=\$,;+]*//g' <<< "$key")

  # shellcheck disable=SC2059
  printf -v formatted_output "$format" "$stripped_key" "$value"

  # If the key exists, change it. Otherwise, add it to the config_file.
  # We search for the key string followed by a word boundary (matched by \>),
  # so if we search for 'setting', 'setting2' won't match.
  if LC_ALL=C grep -q -m 1 $grep_case_insensitive_option -e "${key}\\>" "$config_file"; then
    "${sed_command[@]}" "s/${key}\\>.*/$formatted_output/g$sed_case_insensitive_option" "$config_file"
  else
    # \n is precaution for case where file ends without trailing newline
    printf '\n# Per %s: Set %s in %s\n' "$cce" "$formatted_output" "$config_file" >> "$config_file"
    printf '%s\n' "$formatted_output" >> "$config_file"
  fi
}
replace_or_append '/etc/sysctl.conf' '^net.ipv4.conf.all.accept_source_route' "$sysctl_net_ipv4_conf_all_accept_source_route_value" 'CCE-27037-1'

# END fix for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_all_accept_source_route'

###############################################################################
# BEGIN fix (50 / 114) for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_default_accept_redirects'
###############################################################################
(>&2 echo "Remediating rule 50/114: 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_default_accept_redirects'")

sysctl_net_ipv4_conf_default_accept_redirects_value="0"

#
# Set runtime for net.ipv4.conf.default.accept_redirects
#
/sbin/sysctl -q -n -w net.ipv4.conf.default.accept_redirects="$sysctl_net_ipv4_conf_default_accept_redirects_value"

#
# If net.ipv4.conf.default.accept_redirects present in /etc/sysctl.conf, change value to appropriate value
#	else, add "net.ipv4.conf.default.accept_redirects = value" to /etc/sysctl.conf
#
# Function to replace configuration setting in config file or add the configuration setting if
# it does not exist.
#
# Expects arguments:
#
# config_file:		Configuration file that will be modified
# key:			Configuration option to change
# value:		Value of the configuration option to change
# cce:			The CCE identifier or '@CCENUM@' if no CCE identifier exists
# format:		The printf-like format string that will be given stripped key and value as arguments,
#			so e.g. '%s=%s' will result in key=value subsitution (i.e. without spaces around =)
#
# Optional arugments:
#
# format:		Optional argument to specify the format of how key/value should be
# 			modified/appended in the configuration file. The default is key = value.
#
# Example Call(s):
#
#     With default format of 'key = value':
#     replace_or_append '/etc/sysctl.conf' '^kernel.randomize_va_space' '2' '@CCENUM@'
#
#     With custom key/value format:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' 'disabled' '@CCENUM@' '%s=%s'
#
#     With a variable:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' $var_selinux_state '@CCENUM@' '%s=%s'
#
function replace_or_append {
  local default_format='%s = %s' case_insensitive_mode=yes sed_case_insensitive_option='' grep_case_insensitive_option=''
  local config_file=$1
  local key=$2
  local value=$3
  local cce=$4
  local format=$5

  if [ "$case_insensitive_mode" = yes ]; then
    sed_case_insensitive_option="i"
    grep_case_insensitive_option="-i"
  fi
  [ -n "$format" ] || format="$default_format"
  # Check sanity of the input
  [ $# -ge "3" ] || { echo "Usage: replace_or_append <config_file_location> <key_to_search> <new_value> [<CCE number or literal '@CCENUM@' if unknown>] [printf-like format, default is '$default_format']" >&2; exit 1; }

  # Test if the config_file is a symbolic link. If so, use --follow-symlinks with sed.
  # Otherwise, regular sed command will do.
  sed_command=('sed' '-i')
  if test -L "$config_file"; then
    sed_command+=('--follow-symlinks')
  fi

  # Test that the cce arg is not empty or does not equal @CCENUM@.
  # If @CCENUM@ exists, it means that there is no CCE assigned.
  if [ -n "$cce" ] && [ "$cce" != '@CCENUM@' ]; then
    cce="${cce}"
  else
    cce="CCE"
  fi

  # Strip any search characters in the key arg so that the key can be replaced without
  # adding any search characters to the config file.
  stripped_key=$(sed 's/[\^=\$,;+]*//g' <<< "$key")

  # shellcheck disable=SC2059
  printf -v formatted_output "$format" "$stripped_key" "$value"

  # If the key exists, change it. Otherwise, add it to the config_file.
  # We search for the key string followed by a word boundary (matched by \>),
  # so if we search for 'setting', 'setting2' won't match.
  if LC_ALL=C grep -q -m 1 $grep_case_insensitive_option -e "${key}\\>" "$config_file"; then
    "${sed_command[@]}" "s/${key}\\>.*/$formatted_output/g$sed_case_insensitive_option" "$config_file"
  else
    # \n is precaution for case where file ends without trailing newline
    printf '\n# Per %s: Set %s in %s\n' "$cce" "$formatted_output" "$config_file" >> "$config_file"
    printf '%s\n' "$formatted_output" >> "$config_file"
  fi
}
replace_or_append '/etc/sysctl.conf' '^net.ipv4.conf.default.accept_redirects' "$sysctl_net_ipv4_conf_default_accept_redirects_value" 'CCE-27015-7'

# END fix for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_default_accept_redirects'

###############################################################################
# BEGIN fix (51 / 114) for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_all_rp_filter'
###############################################################################
(>&2 echo "Remediating rule 51/114: 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_all_rp_filter'")

sysctl_net_ipv4_conf_all_rp_filter_value="1"

#
# Set runtime for net.ipv4.conf.all.rp_filter
#
/sbin/sysctl -q -n -w net.ipv4.conf.all.rp_filter="$sysctl_net_ipv4_conf_all_rp_filter_value"

#
# If net.ipv4.conf.all.rp_filter present in /etc/sysctl.conf, change value to appropriate value
#	else, add "net.ipv4.conf.all.rp_filter = value" to /etc/sysctl.conf
#
# Function to replace configuration setting in config file or add the configuration setting if
# it does not exist.
#
# Expects arguments:
#
# config_file:		Configuration file that will be modified
# key:			Configuration option to change
# value:		Value of the configuration option to change
# cce:			The CCE identifier or '@CCENUM@' if no CCE identifier exists
# format:		The printf-like format string that will be given stripped key and value as arguments,
#			so e.g. '%s=%s' will result in key=value subsitution (i.e. without spaces around =)
#
# Optional arugments:
#
# format:		Optional argument to specify the format of how key/value should be
# 			modified/appended in the configuration file. The default is key = value.
#
# Example Call(s):
#
#     With default format of 'key = value':
#     replace_or_append '/etc/sysctl.conf' '^kernel.randomize_va_space' '2' '@CCENUM@'
#
#     With custom key/value format:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' 'disabled' '@CCENUM@' '%s=%s'
#
#     With a variable:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' $var_selinux_state '@CCENUM@' '%s=%s'
#
function replace_or_append {
  local default_format='%s = %s' case_insensitive_mode=yes sed_case_insensitive_option='' grep_case_insensitive_option=''
  local config_file=$1
  local key=$2
  local value=$3
  local cce=$4
  local format=$5

  if [ "$case_insensitive_mode" = yes ]; then
    sed_case_insensitive_option="i"
    grep_case_insensitive_option="-i"
  fi
  [ -n "$format" ] || format="$default_format"
  # Check sanity of the input
  [ $# -ge "3" ] || { echo "Usage: replace_or_append <config_file_location> <key_to_search> <new_value> [<CCE number or literal '@CCENUM@' if unknown>] [printf-like format, default is '$default_format']" >&2; exit 1; }

  # Test if the config_file is a symbolic link. If so, use --follow-symlinks with sed.
  # Otherwise, regular sed command will do.
  sed_command=('sed' '-i')
  if test -L "$config_file"; then
    sed_command+=('--follow-symlinks')
  fi

  # Test that the cce arg is not empty or does not equal @CCENUM@.
  # If @CCENUM@ exists, it means that there is no CCE assigned.
  if [ -n "$cce" ] && [ "$cce" != '@CCENUM@' ]; then
    cce="${cce}"
  else
    cce="CCE"
  fi

  # Strip any search characters in the key arg so that the key can be replaced without
  # adding any search characters to the config file.
  stripped_key=$(sed 's/[\^=\$,;+]*//g' <<< "$key")

  # shellcheck disable=SC2059
  printf -v formatted_output "$format" "$stripped_key" "$value"

  # If the key exists, change it. Otherwise, add it to the config_file.
  # We search for the key string followed by a word boundary (matched by \>),
  # so if we search for 'setting', 'setting2' won't match.
  if LC_ALL=C grep -q -m 1 $grep_case_insensitive_option -e "${key}\\>" "$config_file"; then
    "${sed_command[@]}" "s/${key}\\>.*/$formatted_output/g$sed_case_insensitive_option" "$config_file"
  else
    # \n is precaution for case where file ends without trailing newline
    printf '\n# Per %s: Set %s in %s\n' "$cce" "$formatted_output" "$config_file" >> "$config_file"
    printf '%s\n' "$formatted_output" >> "$config_file"
  fi
}
replace_or_append '/etc/sysctl.conf' '^net.ipv4.conf.all.rp_filter' "$sysctl_net_ipv4_conf_all_rp_filter_value" 'CCE-26979-5'

# END fix for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_all_rp_filter'

###############################################################################
# BEGIN fix (52 / 114) for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_default_send_redirects'
###############################################################################
(>&2 echo "Remediating rule 52/114: 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_default_send_redirects'")


#
# Set runtime for net.ipv4.conf.default.send_redirects
#
/sbin/sysctl -q -n -w net.ipv4.conf.default.send_redirects="0"

#
# If net.ipv4.conf.default.send_redirects present in /etc/sysctl.conf, change value to "0"
#	else, add "net.ipv4.conf.default.send_redirects = 0" to /etc/sysctl.conf
#
# Function to replace configuration setting in config file or add the configuration setting if
# it does not exist.
#
# Expects arguments:
#
# config_file:		Configuration file that will be modified
# key:			Configuration option to change
# value:		Value of the configuration option to change
# cce:			The CCE identifier or '@CCENUM@' if no CCE identifier exists
# format:		The printf-like format string that will be given stripped key and value as arguments,
#			so e.g. '%s=%s' will result in key=value subsitution (i.e. without spaces around =)
#
# Optional arugments:
#
# format:		Optional argument to specify the format of how key/value should be
# 			modified/appended in the configuration file. The default is key = value.
#
# Example Call(s):
#
#     With default format of 'key = value':
#     replace_or_append '/etc/sysctl.conf' '^kernel.randomize_va_space' '2' '@CCENUM@'
#
#     With custom key/value format:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' 'disabled' '@CCENUM@' '%s=%s'
#
#     With a variable:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' $var_selinux_state '@CCENUM@' '%s=%s'
#
function replace_or_append {
  local default_format='%s = %s' case_insensitive_mode=yes sed_case_insensitive_option='' grep_case_insensitive_option=''
  local config_file=$1
  local key=$2
  local value=$3
  local cce=$4
  local format=$5

  if [ "$case_insensitive_mode" = yes ]; then
    sed_case_insensitive_option="i"
    grep_case_insensitive_option="-i"
  fi
  [ -n "$format" ] || format="$default_format"
  # Check sanity of the input
  [ $# -ge "3" ] || { echo "Usage: replace_or_append <config_file_location> <key_to_search> <new_value> [<CCE number or literal '@CCENUM@' if unknown>] [printf-like format, default is '$default_format']" >&2; exit 1; }

  # Test if the config_file is a symbolic link. If so, use --follow-symlinks with sed.
  # Otherwise, regular sed command will do.
  sed_command=('sed' '-i')
  if test -L "$config_file"; then
    sed_command+=('--follow-symlinks')
  fi

  # Test that the cce arg is not empty or does not equal @CCENUM@.
  # If @CCENUM@ exists, it means that there is no CCE assigned.
  if [ -n "$cce" ] && [ "$cce" != '@CCENUM@' ]; then
    cce="${cce}"
  else
    cce="CCE"
  fi

  # Strip any search characters in the key arg so that the key can be replaced without
  # adding any search characters to the config file.
  stripped_key=$(sed 's/[\^=\$,;+]*//g' <<< "$key")

  # shellcheck disable=SC2059
  printf -v formatted_output "$format" "$stripped_key" "$value"

  # If the key exists, change it. Otherwise, add it to the config_file.
  # We search for the key string followed by a word boundary (matched by \>),
  # so if we search for 'setting', 'setting2' won't match.
  if LC_ALL=C grep -q -m 1 $grep_case_insensitive_option -e "${key}\\>" "$config_file"; then
    "${sed_command[@]}" "s/${key}\\>.*/$formatted_output/g$sed_case_insensitive_option" "$config_file"
  else
    # \n is precaution for case where file ends without trailing newline
    printf '\n# Per %s: Set %s in %s\n' "$cce" "$formatted_output" "$config_file" >> "$config_file"
    printf '%s\n' "$formatted_output" >> "$config_file"
  fi
}
replace_or_append '/etc/sysctl.conf' '^net.ipv4.conf.default.send_redirects' "0" 'CCE-27001-7'

# END fix for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_default_send_redirects'

###############################################################################
# BEGIN fix (53 / 114) for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_all_send_redirects'
###############################################################################
(>&2 echo "Remediating rule 53/114: 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_all_send_redirects'")


#
# Set runtime for net.ipv4.conf.all.send_redirects
#
/sbin/sysctl -q -n -w net.ipv4.conf.all.send_redirects="0"

#
# If net.ipv4.conf.all.send_redirects present in /etc/sysctl.conf, change value to "0"
#	else, add "net.ipv4.conf.all.send_redirects = 0" to /etc/sysctl.conf
#
# Function to replace configuration setting in config file or add the configuration setting if
# it does not exist.
#
# Expects arguments:
#
# config_file:		Configuration file that will be modified
# key:			Configuration option to change
# value:		Value of the configuration option to change
# cce:			The CCE identifier or '@CCENUM@' if no CCE identifier exists
# format:		The printf-like format string that will be given stripped key and value as arguments,
#			so e.g. '%s=%s' will result in key=value subsitution (i.e. without spaces around =)
#
# Optional arugments:
#
# format:		Optional argument to specify the format of how key/value should be
# 			modified/appended in the configuration file. The default is key = value.
#
# Example Call(s):
#
#     With default format of 'key = value':
#     replace_or_append '/etc/sysctl.conf' '^kernel.randomize_va_space' '2' '@CCENUM@'
#
#     With custom key/value format:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' 'disabled' '@CCENUM@' '%s=%s'
#
#     With a variable:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' $var_selinux_state '@CCENUM@' '%s=%s'
#
function replace_or_append {
  local default_format='%s = %s' case_insensitive_mode=yes sed_case_insensitive_option='' grep_case_insensitive_option=''
  local config_file=$1
  local key=$2
  local value=$3
  local cce=$4
  local format=$5

  if [ "$case_insensitive_mode" = yes ]; then
    sed_case_insensitive_option="i"
    grep_case_insensitive_option="-i"
  fi
  [ -n "$format" ] || format="$default_format"
  # Check sanity of the input
  [ $# -ge "3" ] || { echo "Usage: replace_or_append <config_file_location> <key_to_search> <new_value> [<CCE number or literal '@CCENUM@' if unknown>] [printf-like format, default is '$default_format']" >&2; exit 1; }

  # Test if the config_file is a symbolic link. If so, use --follow-symlinks with sed.
  # Otherwise, regular sed command will do.
  sed_command=('sed' '-i')
  if test -L "$config_file"; then
    sed_command+=('--follow-symlinks')
  fi

  # Test that the cce arg is not empty or does not equal @CCENUM@.
  # If @CCENUM@ exists, it means that there is no CCE assigned.
  if [ -n "$cce" ] && [ "$cce" != '@CCENUM@' ]; then
    cce="${cce}"
  else
    cce="CCE"
  fi

  # Strip any search characters in the key arg so that the key can be replaced without
  # adding any search characters to the config file.
  stripped_key=$(sed 's/[\^=\$,;+]*//g' <<< "$key")

  # shellcheck disable=SC2059
  printf -v formatted_output "$format" "$stripped_key" "$value"

  # If the key exists, change it. Otherwise, add it to the config_file.
  # We search for the key string followed by a word boundary (matched by \>),
  # so if we search for 'setting', 'setting2' won't match.
  if LC_ALL=C grep -q -m 1 $grep_case_insensitive_option -e "${key}\\>" "$config_file"; then
    "${sed_command[@]}" "s/${key}\\>.*/$formatted_output/g$sed_case_insensitive_option" "$config_file"
  else
    # \n is precaution for case where file ends without trailing newline
    printf '\n# Per %s: Set %s in %s\n' "$cce" "$formatted_output" "$config_file" >> "$config_file"
    printf '%s\n' "$formatted_output" >> "$config_file"
  fi
}
replace_or_append '/etc/sysctl.conf' '^net.ipv4.conf.all.send_redirects' "0" 'CCE-27004-1'

# END fix for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_conf_all_send_redirects'

###############################################################################
# BEGIN fix (54 / 114) for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv6_conf_default_accept_redirects'
###############################################################################
(>&2 echo "Remediating rule 54/114: 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv6_conf_default_accept_redirects'")

sysctl_net_ipv6_conf_default_accept_redirects_value="0"

#
# Set runtime for net.ipv6.conf.default.accept_redirects
#
/sbin/sysctl -q -n -w net.ipv6.conf.default.accept_redirects="$sysctl_net_ipv6_conf_default_accept_redirects_value"

#
# If net.ipv6.conf.default.accept_redirects present in /etc/sysctl.conf, change value to appropriate value
#	else, add "net.ipv6.conf.default.accept_redirects = value" to /etc/sysctl.conf
#
# Function to replace configuration setting in config file or add the configuration setting if
# it does not exist.
#
# Expects arguments:
#
# config_file:		Configuration file that will be modified
# key:			Configuration option to change
# value:		Value of the configuration option to change
# cce:			The CCE identifier or '@CCENUM@' if no CCE identifier exists
# format:		The printf-like format string that will be given stripped key and value as arguments,
#			so e.g. '%s=%s' will result in key=value subsitution (i.e. without spaces around =)
#
# Optional arugments:
#
# format:		Optional argument to specify the format of how key/value should be
# 			modified/appended in the configuration file. The default is key = value.
#
# Example Call(s):
#
#     With default format of 'key = value':
#     replace_or_append '/etc/sysctl.conf' '^kernel.randomize_va_space' '2' '@CCENUM@'
#
#     With custom key/value format:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' 'disabled' '@CCENUM@' '%s=%s'
#
#     With a variable:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' $var_selinux_state '@CCENUM@' '%s=%s'
#
function replace_or_append {
  local default_format='%s = %s' case_insensitive_mode=yes sed_case_insensitive_option='' grep_case_insensitive_option=''
  local config_file=$1
  local key=$2
  local value=$3
  local cce=$4
  local format=$5

  if [ "$case_insensitive_mode" = yes ]; then
    sed_case_insensitive_option="i"
    grep_case_insensitive_option="-i"
  fi
  [ -n "$format" ] || format="$default_format"
  # Check sanity of the input
  [ $# -ge "3" ] || { echo "Usage: replace_or_append <config_file_location> <key_to_search> <new_value> [<CCE number or literal '@CCENUM@' if unknown>] [printf-like format, default is '$default_format']" >&2; exit 1; }

  # Test if the config_file is a symbolic link. If so, use --follow-symlinks with sed.
  # Otherwise, regular sed command will do.
  sed_command=('sed' '-i')
  if test -L "$config_file"; then
    sed_command+=('--follow-symlinks')
  fi

  # Test that the cce arg is not empty or does not equal @CCENUM@.
  # If @CCENUM@ exists, it means that there is no CCE assigned.
  if [ -n "$cce" ] && [ "$cce" != '@CCENUM@' ]; then
    cce="${cce}"
  else
    cce="CCE"
  fi

  # Strip any search characters in the key arg so that the key can be replaced without
  # adding any search characters to the config file.
  stripped_key=$(sed 's/[\^=\$,;+]*//g' <<< "$key")

  # shellcheck disable=SC2059
  printf -v formatted_output "$format" "$stripped_key" "$value"

  # If the key exists, change it. Otherwise, add it to the config_file.
  # We search for the key string followed by a word boundary (matched by \>),
  # so if we search for 'setting', 'setting2' won't match.
  if LC_ALL=C grep -q -m 1 $grep_case_insensitive_option -e "${key}\\>" "$config_file"; then
    "${sed_command[@]}" "s/${key}\\>.*/$formatted_output/g$sed_case_insensitive_option" "$config_file"
  else
    # \n is precaution for case where file ends without trailing newline
    printf '\n# Per %s: Set %s in %s\n' "$cce" "$formatted_output" "$config_file" >> "$config_file"
    printf '%s\n' "$formatted_output" >> "$config_file"
  fi
}
replace_or_append '/etc/sysctl.conf' '^net.ipv6.conf.default.accept_redirects' "$sysctl_net_ipv6_conf_default_accept_redirects_value" 'CCE-27166-8'

# END fix for 'xccdf_org.ssgproject.content_rule_sysctl_net_ipv6_conf_default_accept_redirects'

###############################################################################
# BEGIN fix (55 / 114) for 'xccdf_org.ssgproject.content_rule_kernel_module_sctp_disabled'
###############################################################################
(>&2 echo "Remediating rule 55/114: 'xccdf_org.ssgproject.content_rule_kernel_module_sctp_disabled'")
if LC_ALL=C grep -q -m 1 "^install sctp" /etc/modprobe.d/sctp.conf ; then
	sed -i 's/^install sctp.*/install sctp /bin/true/g' /etc/modprobe.d/sctp.conf
else
	echo -e "\n# Disable per security requirements" >> /etc/modprobe.d/sctp.conf
	echo "install sctp /bin/true" >> /etc/modprobe.d/sctp.conf
fi

# END fix for 'xccdf_org.ssgproject.content_rule_kernel_module_sctp_disabled'

###############################################################################
# BEGIN fix (56 / 114) for 'xccdf_org.ssgproject.content_rule_kernel_module_tipc_disabled'
###############################################################################
(>&2 echo "Remediating rule 56/114: 'xccdf_org.ssgproject.content_rule_kernel_module_tipc_disabled'")
if LC_ALL=C grep -q -m 1 "^install tipc" /etc/modprobe.d/tipc.conf ; then
	sed -i 's/^install tipc.*/install tipc /bin/true/g' /etc/modprobe.d/tipc.conf
else
	echo -e "\n# Disable per security requirements" >> /etc/modprobe.d/tipc.conf
	echo "install tipc /bin/true" >> /etc/modprobe.d/tipc.conf
fi

# END fix for 'xccdf_org.ssgproject.content_rule_kernel_module_tipc_disabled'

###############################################################################
# BEGIN fix (57 / 114) for 'xccdf_org.ssgproject.content_rule_kernel_module_dccp_disabled'
###############################################################################
(>&2 echo "Remediating rule 57/114: 'xccdf_org.ssgproject.content_rule_kernel_module_dccp_disabled'")
if LC_ALL=C grep -q -m 1 "^install dccp" /etc/modprobe.d/dccp.conf ; then
	sed -i 's/^install dccp.*/install dccp /bin/true/g' /etc/modprobe.d/dccp.conf
else
	echo -e "\n# Disable per security requirements" >> /etc/modprobe.d/dccp.conf
	echo "install dccp /bin/true" >> /etc/modprobe.d/dccp.conf
fi

# END fix for 'xccdf_org.ssgproject.content_rule_kernel_module_dccp_disabled'

###############################################################################
# BEGIN fix (58 / 114) for 'xccdf_org.ssgproject.content_rule_kernel_module_rds_disabled'
###############################################################################
(>&2 echo "Remediating rule 58/114: 'xccdf_org.ssgproject.content_rule_kernel_module_rds_disabled'")
if LC_ALL=C grep -q -m 1 "^install rds" /etc/modprobe.d/rds.conf ; then
	sed -i 's/^install rds.*/install rds /bin/true/g' /etc/modprobe.d/rds.conf
else
	echo -e "\n# Disable per security requirements" >> /etc/modprobe.d/rds.conf
	echo "install rds /bin/true" >> /etc/modprobe.d/rds.conf
fi

# END fix for 'xccdf_org.ssgproject.content_rule_kernel_module_rds_disabled'

###############################################################################
# BEGIN fix (59 / 114) for 'xccdf_org.ssgproject.content_rule_grub_legacy_password'
###############################################################################
(>&2 echo "Remediating rule 59/114: 'xccdf_org.ssgproject.content_rule_grub_legacy_password'")
(>&2 echo "FIX FOR THIS RULE 'xccdf_org.ssgproject.content_rule_grub_legacy_password' IS MISSING!")

# END fix for 'xccdf_org.ssgproject.content_rule_grub_legacy_password'

###############################################################################
# BEGIN fix (60 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_sysadmin_actions'
###############################################################################
(>&2 echo "Remediating rule 60/114: 'xccdf_org.ssgproject.content_rule_audit_rules_sysadmin_actions'")


# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix audit file system object watch rule for given path:
# * if rule exists, also verifies the -w bits match the requirements
# * if rule doesn't exist yet, appends expected rule form to $files_to_inspect
#   audit rules file, depending on the tool which was used to load audit rules
#
# Expects four arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules'
# * path                        	value of -w audit rule's argument
# * required access bits        	value of -p audit rule's argument
# * key                         	value of -k audit rule's argument
#
# Example call:
#
#       fix_audit_watch_rule "auditctl" "/etc/localtime" "wa" "audit_time_rules"
#
function fix_audit_watch_rule {

# Load function arguments into local variables
local tool="$1"
local path="$2"
local required_access_bits="$3"
local key="$4"

# Check sanity of the input
if [ $# -ne "4" ]
then
	echo "Usage: fix_audit_watch_rule 'tool' 'path' 'bits' 'key'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
#
# -----------------------------------------------------------------------------------------
# Tool used to load audit rules	| Rule already defined	|  Audit rules file to inspect	  |
# -----------------------------------------------------------------------------------------
#	auditctl		|     Doesn't matter	|  /etc/audit/audit.rules	  |
# -----------------------------------------------------------------------------------------
# 	augenrules		|          Yes		|  /etc/audit/rules.d/*.rules	  |
# 	augenrules		|          No		|  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
declare -a files_to_inspect
files_to_inspect=()

# Check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	exit 1
# If the audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# into the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules')
# If the audit is 'augenrules', then check if rule is already defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to list of files for inspection.
# If rule isn't defined, add '/etc/audit/rules.d/$key.rules' to list of files for inspection.
elif [ "$tool" == 'augenrules' ]
then
	readarray -t matches < <(grep -P "[\s]*-w[\s]+$path" /etc/audit/rules.d/*.rules)

	# For each of the matched entries
	for match in "${matches[@]}"
	do
		# Extract filepath from the match
		rulesd_audit_file=$(echo $match | cut -f1 -d ':')
		# Append that path into list of files for inspection
		files_to_inspect+=("$rulesd_audit_file")
	done
	# Case when particular audit rule isn't defined yet
	if [ "${#files_to_inspect[@]}" -eq "0" ]
	then
		# Append '/etc/audit/rules.d/$key.rules' into list of files for inspection
		local key_rule_file="/etc/audit/rules.d/$key.rules"
		# If the $key.rules file doesn't exist yet, create it with correct permissions
		if [ ! -e "$key_rule_file" ]
		then
			touch "$key_rule_file"
			chmod 0640 "$key_rule_file"
		fi

		files_to_inspect+=("$key_rule_file")
	fi
fi

# Finally perform the inspection and possible subsequent audit rule
# correction for each of the files previously identified for inspection
for audit_rules_file in "${files_to_inspect[@]}"
do

	# Check if audit watch file system object rule for given path already present
	if grep -q -P -- "[\s]*-w[\s]+$path" "$audit_rules_file"
	then
		# Rule is found => verify yet if existing rule definition contains
		# all of the required access type bits

		# Escape slashes in path for use in sed pattern below
		local esc_path=${path//$'/'/$'\/'}
		# Define BRE whitespace class shortcut
		local sp="[[:space:]]"
		# Extract current permission access types (e.g. -p [r|w|x|a] values) from audit rule
		current_access_bits=$(sed -ne "s/$sp*-w$sp\+$esc_path$sp\+-p$sp\+\([rxwa]\{1,4\}\).*/\1/p" "$audit_rules_file")
		# Split required access bits string into characters array
		# (to check bit's presence for one bit at a time)
		for access_bit in $(echo "$required_access_bits" | grep -o .)
		do
			# For each from the required access bits (e.g. 'w', 'a') check
			# if they are already present in current access bits for rule.
			# If not, append that bit at the end
			if ! grep -q "$access_bit" <<< "$current_access_bits"
			then
				# Concatenate the existing mask with the missing bit
				current_access_bits="$current_access_bits$access_bit"
			fi
		done
		# Propagate the updated rule's access bits (original + the required
		# ones) back into the /etc/audit/audit.rules file for that rule
		sed -i "s/\($sp*-w$sp\+$esc_path$sp\+-p$sp\+\)\([rxwa]\{1,4\}\)\(.*\)/\1$current_access_bits\3/" "$audit_rules_file"
	else
		# Rule isn't present yet. Append it at the end of $audit_rules_file file
		# with proper key

		echo "-w $path -p $required_access_bits -k $key" >> "$audit_rules_file"
	fi
done
}
fix_audit_watch_rule "auditctl" "/etc/sudoers" "wa" "actions"
fix_audit_watch_rule "augenrules" "/etc/sudoers" "wa" "actions"
# Function to fix audit file system object watch rule for given path:
# * if rule exists, also verifies the -w bits match the requirements
# * if rule doesn't exist yet, appends expected rule form to $files_to_inspect
#   audit rules file, depending on the tool which was used to load audit rules
#
# Expects four arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules'
# * path                        	value of -w audit rule's argument
# * required access bits        	value of -p audit rule's argument
# * key                         	value of -k audit rule's argument
#
# Example call:
#
#       fix_audit_watch_rule "auditctl" "/etc/localtime" "wa" "audit_time_rules"
#
function fix_audit_watch_rule {

# Load function arguments into local variables
local tool="$1"
local path="$2"
local required_access_bits="$3"
local key="$4"

# Check sanity of the input
if [ $# -ne "4" ]
then
	echo "Usage: fix_audit_watch_rule 'tool' 'path' 'bits' 'key'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
#
# -----------------------------------------------------------------------------------------
# Tool used to load audit rules	| Rule already defined	|  Audit rules file to inspect	  |
# -----------------------------------------------------------------------------------------
#	auditctl		|     Doesn't matter	|  /etc/audit/audit.rules	  |
# -----------------------------------------------------------------------------------------
# 	augenrules		|          Yes		|  /etc/audit/rules.d/*.rules	  |
# 	augenrules		|          No		|  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
declare -a files_to_inspect
files_to_inspect=()

# Check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	exit 1
# If the audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# into the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules')
# If the audit is 'augenrules', then check if rule is already defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to list of files for inspection.
# If rule isn't defined, add '/etc/audit/rules.d/$key.rules' to list of files for inspection.
elif [ "$tool" == 'augenrules' ]
then
	readarray -t matches < <(grep -P "[\s]*-w[\s]+$path" /etc/audit/rules.d/*.rules)

	# For each of the matched entries
	for match in "${matches[@]}"
	do
		# Extract filepath from the match
		rulesd_audit_file=$(echo $match | cut -f1 -d ':')
		# Append that path into list of files for inspection
		files_to_inspect+=("$rulesd_audit_file")
	done
	# Case when particular audit rule isn't defined yet
	if [ "${#files_to_inspect[@]}" -eq "0" ]
	then
		# Append '/etc/audit/rules.d/$key.rules' into list of files for inspection
		local key_rule_file="/etc/audit/rules.d/$key.rules"
		# If the $key.rules file doesn't exist yet, create it with correct permissions
		if [ ! -e "$key_rule_file" ]
		then
			touch "$key_rule_file"
			chmod 0640 "$key_rule_file"
		fi

		files_to_inspect+=("$key_rule_file")
	fi
fi

# Finally perform the inspection and possible subsequent audit rule
# correction for each of the files previously identified for inspection
for audit_rules_file in "${files_to_inspect[@]}"
do

	# Check if audit watch file system object rule for given path already present
	if grep -q -P -- "[\s]*-w[\s]+$path" "$audit_rules_file"
	then
		# Rule is found => verify yet if existing rule definition contains
		# all of the required access type bits

		# Escape slashes in path for use in sed pattern below
		local esc_path=${path//$'/'/$'\/'}
		# Define BRE whitespace class shortcut
		local sp="[[:space:]]"
		# Extract current permission access types (e.g. -p [r|w|x|a] values) from audit rule
		current_access_bits=$(sed -ne "s/$sp*-w$sp\+$esc_path$sp\+-p$sp\+\([rxwa]\{1,4\}\).*/\1/p" "$audit_rules_file")
		# Split required access bits string into characters array
		# (to check bit's presence for one bit at a time)
		for access_bit in $(echo "$required_access_bits" | grep -o .)
		do
			# For each from the required access bits (e.g. 'w', 'a') check
			# if they are already present in current access bits for rule.
			# If not, append that bit at the end
			if ! grep -q "$access_bit" <<< "$current_access_bits"
			then
				# Concatenate the existing mask with the missing bit
				current_access_bits="$current_access_bits$access_bit"
			fi
		done
		# Propagate the updated rule's access bits (original + the required
		# ones) back into the /etc/audit/audit.rules file for that rule
		sed -i "s/\($sp*-w$sp\+$esc_path$sp\+-p$sp\+\)\([rxwa]\{1,4\}\)\(.*\)/\1$current_access_bits\3/" "$audit_rules_file"
	else
		# Rule isn't present yet. Append it at the end of $audit_rules_file file
		# with proper key

		echo "-w $path -p $required_access_bits -k $key" >> "$audit_rules_file"
	fi
done
}
fix_audit_watch_rule "auditctl" "/etc/sudoers.d" "wa" "actions"
fix_audit_watch_rule "augenrules" "/etc/sudoers.d" "wa" "actions"

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_sysadmin_actions'

###############################################################################
# BEGIN fix (61 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_networkconfig_modification'
###############################################################################
(>&2 echo "Remediating rule 61/114: 'xccdf_org.ssgproject.content_rule_audit_rules_networkconfig_modification'")


# First perform the remediation of the syscall rule
# Retrieve hardware architecture of the underlying system
[ "$(getconf LONG_BIT)" = "32" ] && RULE_ARCHS=("b32") || RULE_ARCHS=("b32" "b64")

for ARCH in "${RULE_ARCHS[@]}"
do
	PATTERN="-a always,exit -F arch=$ARCH -S .* -k *"
	# Use escaped BRE regex to specify rule group
	GROUP="set\(host\|domain\)name"
	FULL_RULE="-a always,exit -F arch=$ARCH -S sethostname -S setdomainname -k audit_rules_networkconfig_modification"
	# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}
	fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
	fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
done

# Then perform the remediations for the watch rules
# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix audit file system object watch rule for given path:
# * if rule exists, also verifies the -w bits match the requirements
# * if rule doesn't exist yet, appends expected rule form to $files_to_inspect
#   audit rules file, depending on the tool which was used to load audit rules
#
# Expects four arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules'
# * path                        	value of -w audit rule's argument
# * required access bits        	value of -p audit rule's argument
# * key                         	value of -k audit rule's argument
#
# Example call:
#
#       fix_audit_watch_rule "auditctl" "/etc/localtime" "wa" "audit_time_rules"
#
function fix_audit_watch_rule {

# Load function arguments into local variables
local tool="$1"
local path="$2"
local required_access_bits="$3"
local key="$4"

# Check sanity of the input
if [ $# -ne "4" ]
then
	echo "Usage: fix_audit_watch_rule 'tool' 'path' 'bits' 'key'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
#
# -----------------------------------------------------------------------------------------
# Tool used to load audit rules	| Rule already defined	|  Audit rules file to inspect	  |
# -----------------------------------------------------------------------------------------
#	auditctl		|     Doesn't matter	|  /etc/audit/audit.rules	  |
# -----------------------------------------------------------------------------------------
# 	augenrules		|          Yes		|  /etc/audit/rules.d/*.rules	  |
# 	augenrules		|          No		|  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
declare -a files_to_inspect
files_to_inspect=()

# Check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	exit 1
# If the audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# into the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules')
# If the audit is 'augenrules', then check if rule is already defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to list of files for inspection.
# If rule isn't defined, add '/etc/audit/rules.d/$key.rules' to list of files for inspection.
elif [ "$tool" == 'augenrules' ]
then
	readarray -t matches < <(grep -P "[\s]*-w[\s]+$path" /etc/audit/rules.d/*.rules)

	# For each of the matched entries
	for match in "${matches[@]}"
	do
		# Extract filepath from the match
		rulesd_audit_file=$(echo $match | cut -f1 -d ':')
		# Append that path into list of files for inspection
		files_to_inspect+=("$rulesd_audit_file")
	done
	# Case when particular audit rule isn't defined yet
	if [ "${#files_to_inspect[@]}" -eq "0" ]
	then
		# Append '/etc/audit/rules.d/$key.rules' into list of files for inspection
		local key_rule_file="/etc/audit/rules.d/$key.rules"
		# If the $key.rules file doesn't exist yet, create it with correct permissions
		if [ ! -e "$key_rule_file" ]
		then
			touch "$key_rule_file"
			chmod 0640 "$key_rule_file"
		fi

		files_to_inspect+=("$key_rule_file")
	fi
fi

# Finally perform the inspection and possible subsequent audit rule
# correction for each of the files previously identified for inspection
for audit_rules_file in "${files_to_inspect[@]}"
do

	# Check if audit watch file system object rule for given path already present
	if grep -q -P -- "[\s]*-w[\s]+$path" "$audit_rules_file"
	then
		# Rule is found => verify yet if existing rule definition contains
		# all of the required access type bits

		# Escape slashes in path for use in sed pattern below
		local esc_path=${path//$'/'/$'\/'}
		# Define BRE whitespace class shortcut
		local sp="[[:space:]]"
		# Extract current permission access types (e.g. -p [r|w|x|a] values) from audit rule
		current_access_bits=$(sed -ne "s/$sp*-w$sp\+$esc_path$sp\+-p$sp\+\([rxwa]\{1,4\}\).*/\1/p" "$audit_rules_file")
		# Split required access bits string into characters array
		# (to check bit's presence for one bit at a time)
		for access_bit in $(echo "$required_access_bits" | grep -o .)
		do
			# For each from the required access bits (e.g. 'w', 'a') check
			# if they are already present in current access bits for rule.
			# If not, append that bit at the end
			if ! grep -q "$access_bit" <<< "$current_access_bits"
			then
				# Concatenate the existing mask with the missing bit
				current_access_bits="$current_access_bits$access_bit"
			fi
		done
		# Propagate the updated rule's access bits (original + the required
		# ones) back into the /etc/audit/audit.rules file for that rule
		sed -i "s/\($sp*-w$sp\+$esc_path$sp\+-p$sp\+\)\([rxwa]\{1,4\}\)\(.*\)/\1$current_access_bits\3/" "$audit_rules_file"
	else
		# Rule isn't present yet. Append it at the end of $audit_rules_file file
		# with proper key

		echo "-w $path -p $required_access_bits -k $key" >> "$audit_rules_file"
	fi
done
}
fix_audit_watch_rule "auditctl" "/etc/issue" "wa" "audit_rules_networkconfig_modification"
fix_audit_watch_rule "augenrules" "/etc/issue" "wa" "audit_rules_networkconfig_modification"
# Function to fix audit file system object watch rule for given path:
# * if rule exists, also verifies the -w bits match the requirements
# * if rule doesn't exist yet, appends expected rule form to $files_to_inspect
#   audit rules file, depending on the tool which was used to load audit rules
#
# Expects four arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules'
# * path                        	value of -w audit rule's argument
# * required access bits        	value of -p audit rule's argument
# * key                         	value of -k audit rule's argument
#
# Example call:
#
#       fix_audit_watch_rule "auditctl" "/etc/localtime" "wa" "audit_time_rules"
#
function fix_audit_watch_rule {

# Load function arguments into local variables
local tool="$1"
local path="$2"
local required_access_bits="$3"
local key="$4"

# Check sanity of the input
if [ $# -ne "4" ]
then
	echo "Usage: fix_audit_watch_rule 'tool' 'path' 'bits' 'key'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
#
# -----------------------------------------------------------------------------------------
# Tool used to load audit rules	| Rule already defined	|  Audit rules file to inspect	  |
# -----------------------------------------------------------------------------------------
#	auditctl		|     Doesn't matter	|  /etc/audit/audit.rules	  |
# -----------------------------------------------------------------------------------------
# 	augenrules		|          Yes		|  /etc/audit/rules.d/*.rules	  |
# 	augenrules		|          No		|  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
declare -a files_to_inspect
files_to_inspect=()

# Check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	exit 1
# If the audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# into the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules')
# If the audit is 'augenrules', then check if rule is already defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to list of files for inspection.
# If rule isn't defined, add '/etc/audit/rules.d/$key.rules' to list of files for inspection.
elif [ "$tool" == 'augenrules' ]
then
	readarray -t matches < <(grep -P "[\s]*-w[\s]+$path" /etc/audit/rules.d/*.rules)

	# For each of the matched entries
	for match in "${matches[@]}"
	do
		# Extract filepath from the match
		rulesd_audit_file=$(echo $match | cut -f1 -d ':')
		# Append that path into list of files for inspection
		files_to_inspect+=("$rulesd_audit_file")
	done
	# Case when particular audit rule isn't defined yet
	if [ "${#files_to_inspect[@]}" -eq "0" ]
	then
		# Append '/etc/audit/rules.d/$key.rules' into list of files for inspection
		local key_rule_file="/etc/audit/rules.d/$key.rules"
		# If the $key.rules file doesn't exist yet, create it with correct permissions
		if [ ! -e "$key_rule_file" ]
		then
			touch "$key_rule_file"
			chmod 0640 "$key_rule_file"
		fi

		files_to_inspect+=("$key_rule_file")
	fi
fi

# Finally perform the inspection and possible subsequent audit rule
# correction for each of the files previously identified for inspection
for audit_rules_file in "${files_to_inspect[@]}"
do

	# Check if audit watch file system object rule for given path already present
	if grep -q -P -- "[\s]*-w[\s]+$path" "$audit_rules_file"
	then
		# Rule is found => verify yet if existing rule definition contains
		# all of the required access type bits

		# Escape slashes in path for use in sed pattern below
		local esc_path=${path//$'/'/$'\/'}
		# Define BRE whitespace class shortcut
		local sp="[[:space:]]"
		# Extract current permission access types (e.g. -p [r|w|x|a] values) from audit rule
		current_access_bits=$(sed -ne "s/$sp*-w$sp\+$esc_path$sp\+-p$sp\+\([rxwa]\{1,4\}\).*/\1/p" "$audit_rules_file")
		# Split required access bits string into characters array
		# (to check bit's presence for one bit at a time)
		for access_bit in $(echo "$required_access_bits" | grep -o .)
		do
			# For each from the required access bits (e.g. 'w', 'a') check
			# if they are already present in current access bits for rule.
			# If not, append that bit at the end
			if ! grep -q "$access_bit" <<< "$current_access_bits"
			then
				# Concatenate the existing mask with the missing bit
				current_access_bits="$current_access_bits$access_bit"
			fi
		done
		# Propagate the updated rule's access bits (original + the required
		# ones) back into the /etc/audit/audit.rules file for that rule
		sed -i "s/\($sp*-w$sp\+$esc_path$sp\+-p$sp\+\)\([rxwa]\{1,4\}\)\(.*\)/\1$current_access_bits\3/" "$audit_rules_file"
	else
		# Rule isn't present yet. Append it at the end of $audit_rules_file file
		# with proper key

		echo "-w $path -p $required_access_bits -k $key" >> "$audit_rules_file"
	fi
done
}
fix_audit_watch_rule "auditctl" "/etc/issue.net" "wa" "audit_rules_networkconfig_modification"
fix_audit_watch_rule "augenrules" "/etc/issue.net" "wa" "audit_rules_networkconfig_modification"
# Function to fix audit file system object watch rule for given path:
# * if rule exists, also verifies the -w bits match the requirements
# * if rule doesn't exist yet, appends expected rule form to $files_to_inspect
#   audit rules file, depending on the tool which was used to load audit rules
#
# Expects four arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules'
# * path                        	value of -w audit rule's argument
# * required access bits        	value of -p audit rule's argument
# * key                         	value of -k audit rule's argument
#
# Example call:
#
#       fix_audit_watch_rule "auditctl" "/etc/localtime" "wa" "audit_time_rules"
#
function fix_audit_watch_rule {

# Load function arguments into local variables
local tool="$1"
local path="$2"
local required_access_bits="$3"
local key="$4"

# Check sanity of the input
if [ $# -ne "4" ]
then
	echo "Usage: fix_audit_watch_rule 'tool' 'path' 'bits' 'key'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
#
# -----------------------------------------------------------------------------------------
# Tool used to load audit rules	| Rule already defined	|  Audit rules file to inspect	  |
# -----------------------------------------------------------------------------------------
#	auditctl		|     Doesn't matter	|  /etc/audit/audit.rules	  |
# -----------------------------------------------------------------------------------------
# 	augenrules		|          Yes		|  /etc/audit/rules.d/*.rules	  |
# 	augenrules		|          No		|  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
declare -a files_to_inspect
files_to_inspect=()

# Check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	exit 1
# If the audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# into the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules')
# If the audit is 'augenrules', then check if rule is already defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to list of files for inspection.
# If rule isn't defined, add '/etc/audit/rules.d/$key.rules' to list of files for inspection.
elif [ "$tool" == 'augenrules' ]
then
	readarray -t matches < <(grep -P "[\s]*-w[\s]+$path" /etc/audit/rules.d/*.rules)

	# For each of the matched entries
	for match in "${matches[@]}"
	do
		# Extract filepath from the match
		rulesd_audit_file=$(echo $match | cut -f1 -d ':')
		# Append that path into list of files for inspection
		files_to_inspect+=("$rulesd_audit_file")
	done
	# Case when particular audit rule isn't defined yet
	if [ "${#files_to_inspect[@]}" -eq "0" ]
	then
		# Append '/etc/audit/rules.d/$key.rules' into list of files for inspection
		local key_rule_file="/etc/audit/rules.d/$key.rules"
		# If the $key.rules file doesn't exist yet, create it with correct permissions
		if [ ! -e "$key_rule_file" ]
		then
			touch "$key_rule_file"
			chmod 0640 "$key_rule_file"
		fi

		files_to_inspect+=("$key_rule_file")
	fi
fi

# Finally perform the inspection and possible subsequent audit rule
# correction for each of the files previously identified for inspection
for audit_rules_file in "${files_to_inspect[@]}"
do

	# Check if audit watch file system object rule for given path already present
	if grep -q -P -- "[\s]*-w[\s]+$path" "$audit_rules_file"
	then
		# Rule is found => verify yet if existing rule definition contains
		# all of the required access type bits

		# Escape slashes in path for use in sed pattern below
		local esc_path=${path//$'/'/$'\/'}
		# Define BRE whitespace class shortcut
		local sp="[[:space:]]"
		# Extract current permission access types (e.g. -p [r|w|x|a] values) from audit rule
		current_access_bits=$(sed -ne "s/$sp*-w$sp\+$esc_path$sp\+-p$sp\+\([rxwa]\{1,4\}\).*/\1/p" "$audit_rules_file")
		# Split required access bits string into characters array
		# (to check bit's presence for one bit at a time)
		for access_bit in $(echo "$required_access_bits" | grep -o .)
		do
			# For each from the required access bits (e.g. 'w', 'a') check
			# if they are already present in current access bits for rule.
			# If not, append that bit at the end
			if ! grep -q "$access_bit" <<< "$current_access_bits"
			then
				# Concatenate the existing mask with the missing bit
				current_access_bits="$current_access_bits$access_bit"
			fi
		done
		# Propagate the updated rule's access bits (original + the required
		# ones) back into the /etc/audit/audit.rules file for that rule
		sed -i "s/\($sp*-w$sp\+$esc_path$sp\+-p$sp\+\)\([rxwa]\{1,4\}\)\(.*\)/\1$current_access_bits\3/" "$audit_rules_file"
	else
		# Rule isn't present yet. Append it at the end of $audit_rules_file file
		# with proper key

		echo "-w $path -p $required_access_bits -k $key" >> "$audit_rules_file"
	fi
done
}
fix_audit_watch_rule "auditctl" "/etc/hosts" "wa" "audit_rules_networkconfig_modification"
fix_audit_watch_rule "augenrules" "/etc/hosts" "wa" "audit_rules_networkconfig_modification"
# Function to fix audit file system object watch rule for given path:
# * if rule exists, also verifies the -w bits match the requirements
# * if rule doesn't exist yet, appends expected rule form to $files_to_inspect
#   audit rules file, depending on the tool which was used to load audit rules
#
# Expects four arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules'
# * path                        	value of -w audit rule's argument
# * required access bits        	value of -p audit rule's argument
# * key                         	value of -k audit rule's argument
#
# Example call:
#
#       fix_audit_watch_rule "auditctl" "/etc/localtime" "wa" "audit_time_rules"
#
function fix_audit_watch_rule {

# Load function arguments into local variables
local tool="$1"
local path="$2"
local required_access_bits="$3"
local key="$4"

# Check sanity of the input
if [ $# -ne "4" ]
then
	echo "Usage: fix_audit_watch_rule 'tool' 'path' 'bits' 'key'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
#
# -----------------------------------------------------------------------------------------
# Tool used to load audit rules	| Rule already defined	|  Audit rules file to inspect	  |
# -----------------------------------------------------------------------------------------
#	auditctl		|     Doesn't matter	|  /etc/audit/audit.rules	  |
# -----------------------------------------------------------------------------------------
# 	augenrules		|          Yes		|  /etc/audit/rules.d/*.rules	  |
# 	augenrules		|          No		|  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
declare -a files_to_inspect
files_to_inspect=()

# Check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	exit 1
# If the audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# into the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules')
# If the audit is 'augenrules', then check if rule is already defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to list of files for inspection.
# If rule isn't defined, add '/etc/audit/rules.d/$key.rules' to list of files for inspection.
elif [ "$tool" == 'augenrules' ]
then
	readarray -t matches < <(grep -P "[\s]*-w[\s]+$path" /etc/audit/rules.d/*.rules)

	# For each of the matched entries
	for match in "${matches[@]}"
	do
		# Extract filepath from the match
		rulesd_audit_file=$(echo $match | cut -f1 -d ':')
		# Append that path into list of files for inspection
		files_to_inspect+=("$rulesd_audit_file")
	done
	# Case when particular audit rule isn't defined yet
	if [ "${#files_to_inspect[@]}" -eq "0" ]
	then
		# Append '/etc/audit/rules.d/$key.rules' into list of files for inspection
		local key_rule_file="/etc/audit/rules.d/$key.rules"
		# If the $key.rules file doesn't exist yet, create it with correct permissions
		if [ ! -e "$key_rule_file" ]
		then
			touch "$key_rule_file"
			chmod 0640 "$key_rule_file"
		fi

		files_to_inspect+=("$key_rule_file")
	fi
fi

# Finally perform the inspection and possible subsequent audit rule
# correction for each of the files previously identified for inspection
for audit_rules_file in "${files_to_inspect[@]}"
do

	# Check if audit watch file system object rule for given path already present
	if grep -q -P -- "[\s]*-w[\s]+$path" "$audit_rules_file"
	then
		# Rule is found => verify yet if existing rule definition contains
		# all of the required access type bits

		# Escape slashes in path for use in sed pattern below
		local esc_path=${path//$'/'/$'\/'}
		# Define BRE whitespace class shortcut
		local sp="[[:space:]]"
		# Extract current permission access types (e.g. -p [r|w|x|a] values) from audit rule
		current_access_bits=$(sed -ne "s/$sp*-w$sp\+$esc_path$sp\+-p$sp\+\([rxwa]\{1,4\}\).*/\1/p" "$audit_rules_file")
		# Split required access bits string into characters array
		# (to check bit's presence for one bit at a time)
		for access_bit in $(echo "$required_access_bits" | grep -o .)
		do
			# For each from the required access bits (e.g. 'w', 'a') check
			# if they are already present in current access bits for rule.
			# If not, append that bit at the end
			if ! grep -q "$access_bit" <<< "$current_access_bits"
			then
				# Concatenate the existing mask with the missing bit
				current_access_bits="$current_access_bits$access_bit"
			fi
		done
		# Propagate the updated rule's access bits (original + the required
		# ones) back into the /etc/audit/audit.rules file for that rule
		sed -i "s/\($sp*-w$sp\+$esc_path$sp\+-p$sp\+\)\([rxwa]\{1,4\}\)\(.*\)/\1$current_access_bits\3/" "$audit_rules_file"
	else
		# Rule isn't present yet. Append it at the end of $audit_rules_file file
		# with proper key

		echo "-w $path -p $required_access_bits -k $key" >> "$audit_rules_file"
	fi
done
}
fix_audit_watch_rule "auditctl" "/etc/sysconfig/network" "wa" "audit_rules_networkconfig_modification"
fix_audit_watch_rule "augenrules" "/etc/sysconfig/network" "wa" "audit_rules_networkconfig_modification"

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_networkconfig_modification'

###############################################################################
# BEGIN fix (62 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_usergroup_modification'
###############################################################################
(>&2 echo "Remediating rule 62/114: 'xccdf_org.ssgproject.content_rule_audit_rules_usergroup_modification'")


# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix audit file system object watch rule for given path:
# * if rule exists, also verifies the -w bits match the requirements
# * if rule doesn't exist yet, appends expected rule form to $files_to_inspect
#   audit rules file, depending on the tool which was used to load audit rules
#
# Expects four arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules'
# * path                        	value of -w audit rule's argument
# * required access bits        	value of -p audit rule's argument
# * key                         	value of -k audit rule's argument
#
# Example call:
#
#       fix_audit_watch_rule "auditctl" "/etc/localtime" "wa" "audit_time_rules"
#
function fix_audit_watch_rule {

# Load function arguments into local variables
local tool="$1"
local path="$2"
local required_access_bits="$3"
local key="$4"

# Check sanity of the input
if [ $# -ne "4" ]
then
	echo "Usage: fix_audit_watch_rule 'tool' 'path' 'bits' 'key'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
#
# -----------------------------------------------------------------------------------------
# Tool used to load audit rules	| Rule already defined	|  Audit rules file to inspect	  |
# -----------------------------------------------------------------------------------------
#	auditctl		|     Doesn't matter	|  /etc/audit/audit.rules	  |
# -----------------------------------------------------------------------------------------
# 	augenrules		|          Yes		|  /etc/audit/rules.d/*.rules	  |
# 	augenrules		|          No		|  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
declare -a files_to_inspect
files_to_inspect=()

# Check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	exit 1
# If the audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# into the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules')
# If the audit is 'augenrules', then check if rule is already defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to list of files for inspection.
# If rule isn't defined, add '/etc/audit/rules.d/$key.rules' to list of files for inspection.
elif [ "$tool" == 'augenrules' ]
then
	readarray -t matches < <(grep -P "[\s]*-w[\s]+$path" /etc/audit/rules.d/*.rules)

	# For each of the matched entries
	for match in "${matches[@]}"
	do
		# Extract filepath from the match
		rulesd_audit_file=$(echo $match | cut -f1 -d ':')
		# Append that path into list of files for inspection
		files_to_inspect+=("$rulesd_audit_file")
	done
	# Case when particular audit rule isn't defined yet
	if [ "${#files_to_inspect[@]}" -eq "0" ]
	then
		# Append '/etc/audit/rules.d/$key.rules' into list of files for inspection
		local key_rule_file="/etc/audit/rules.d/$key.rules"
		# If the $key.rules file doesn't exist yet, create it with correct permissions
		if [ ! -e "$key_rule_file" ]
		then
			touch "$key_rule_file"
			chmod 0640 "$key_rule_file"
		fi

		files_to_inspect+=("$key_rule_file")
	fi
fi

# Finally perform the inspection and possible subsequent audit rule
# correction for each of the files previously identified for inspection
for audit_rules_file in "${files_to_inspect[@]}"
do

	# Check if audit watch file system object rule for given path already present
	if grep -q -P -- "[\s]*-w[\s]+$path" "$audit_rules_file"
	then
		# Rule is found => verify yet if existing rule definition contains
		# all of the required access type bits

		# Escape slashes in path for use in sed pattern below
		local esc_path=${path//$'/'/$'\/'}
		# Define BRE whitespace class shortcut
		local sp="[[:space:]]"
		# Extract current permission access types (e.g. -p [r|w|x|a] values) from audit rule
		current_access_bits=$(sed -ne "s/$sp*-w$sp\+$esc_path$sp\+-p$sp\+\([rxwa]\{1,4\}\).*/\1/p" "$audit_rules_file")
		# Split required access bits string into characters array
		# (to check bit's presence for one bit at a time)
		for access_bit in $(echo "$required_access_bits" | grep -o .)
		do
			# For each from the required access bits (e.g. 'w', 'a') check
			# if they are already present in current access bits for rule.
			# If not, append that bit at the end
			if ! grep -q "$access_bit" <<< "$current_access_bits"
			then
				# Concatenate the existing mask with the missing bit
				current_access_bits="$current_access_bits$access_bit"
			fi
		done
		# Propagate the updated rule's access bits (original + the required
		# ones) back into the /etc/audit/audit.rules file for that rule
		sed -i "s/\($sp*-w$sp\+$esc_path$sp\+-p$sp\+\)\([rxwa]\{1,4\}\)\(.*\)/\1$current_access_bits\3/" "$audit_rules_file"
	else
		# Rule isn't present yet. Append it at the end of $audit_rules_file file
		# with proper key

		echo "-w $path -p $required_access_bits -k $key" >> "$audit_rules_file"
	fi
done
}
fix_audit_watch_rule "auditctl" "/etc/group" "wa" "audit_rules_usergroup_modification"
fix_audit_watch_rule "augenrules" "/etc/group" "wa" "audit_rules_usergroup_modification"
# Function to fix audit file system object watch rule for given path:
# * if rule exists, also verifies the -w bits match the requirements
# * if rule doesn't exist yet, appends expected rule form to $files_to_inspect
#   audit rules file, depending on the tool which was used to load audit rules
#
# Expects four arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules'
# * path                        	value of -w audit rule's argument
# * required access bits        	value of -p audit rule's argument
# * key                         	value of -k audit rule's argument
#
# Example call:
#
#       fix_audit_watch_rule "auditctl" "/etc/localtime" "wa" "audit_time_rules"
#
function fix_audit_watch_rule {

# Load function arguments into local variables
local tool="$1"
local path="$2"
local required_access_bits="$3"
local key="$4"

# Check sanity of the input
if [ $# -ne "4" ]
then
	echo "Usage: fix_audit_watch_rule 'tool' 'path' 'bits' 'key'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
#
# -----------------------------------------------------------------------------------------
# Tool used to load audit rules	| Rule already defined	|  Audit rules file to inspect	  |
# -----------------------------------------------------------------------------------------
#	auditctl		|     Doesn't matter	|  /etc/audit/audit.rules	  |
# -----------------------------------------------------------------------------------------
# 	augenrules		|          Yes		|  /etc/audit/rules.d/*.rules	  |
# 	augenrules		|          No		|  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
declare -a files_to_inspect
files_to_inspect=()

# Check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	exit 1
# If the audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# into the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules')
# If the audit is 'augenrules', then check if rule is already defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to list of files for inspection.
# If rule isn't defined, add '/etc/audit/rules.d/$key.rules' to list of files for inspection.
elif [ "$tool" == 'augenrules' ]
then
	readarray -t matches < <(grep -P "[\s]*-w[\s]+$path" /etc/audit/rules.d/*.rules)

	# For each of the matched entries
	for match in "${matches[@]}"
	do
		# Extract filepath from the match
		rulesd_audit_file=$(echo $match | cut -f1 -d ':')
		# Append that path into list of files for inspection
		files_to_inspect+=("$rulesd_audit_file")
	done
	# Case when particular audit rule isn't defined yet
	if [ "${#files_to_inspect[@]}" -eq "0" ]
	then
		# Append '/etc/audit/rules.d/$key.rules' into list of files for inspection
		local key_rule_file="/etc/audit/rules.d/$key.rules"
		# If the $key.rules file doesn't exist yet, create it with correct permissions
		if [ ! -e "$key_rule_file" ]
		then
			touch "$key_rule_file"
			chmod 0640 "$key_rule_file"
		fi

		files_to_inspect+=("$key_rule_file")
	fi
fi

# Finally perform the inspection and possible subsequent audit rule
# correction for each of the files previously identified for inspection
for audit_rules_file in "${files_to_inspect[@]}"
do

	# Check if audit watch file system object rule for given path already present
	if grep -q -P -- "[\s]*-w[\s]+$path" "$audit_rules_file"
	then
		# Rule is found => verify yet if existing rule definition contains
		# all of the required access type bits

		# Escape slashes in path for use in sed pattern below
		local esc_path=${path//$'/'/$'\/'}
		# Define BRE whitespace class shortcut
		local sp="[[:space:]]"
		# Extract current permission access types (e.g. -p [r|w|x|a] values) from audit rule
		current_access_bits=$(sed -ne "s/$sp*-w$sp\+$esc_path$sp\+-p$sp\+\([rxwa]\{1,4\}\).*/\1/p" "$audit_rules_file")
		# Split required access bits string into characters array
		# (to check bit's presence for one bit at a time)
		for access_bit in $(echo "$required_access_bits" | grep -o .)
		do
			# For each from the required access bits (e.g. 'w', 'a') check
			# if they are already present in current access bits for rule.
			# If not, append that bit at the end
			if ! grep -q "$access_bit" <<< "$current_access_bits"
			then
				# Concatenate the existing mask with the missing bit
				current_access_bits="$current_access_bits$access_bit"
			fi
		done
		# Propagate the updated rule's access bits (original + the required
		# ones) back into the /etc/audit/audit.rules file for that rule
		sed -i "s/\($sp*-w$sp\+$esc_path$sp\+-p$sp\+\)\([rxwa]\{1,4\}\)\(.*\)/\1$current_access_bits\3/" "$audit_rules_file"
	else
		# Rule isn't present yet. Append it at the end of $audit_rules_file file
		# with proper key

		echo "-w $path -p $required_access_bits -k $key" >> "$audit_rules_file"
	fi
done
}
fix_audit_watch_rule "auditctl" "/etc/passwd" "wa" "audit_rules_usergroup_modification"
fix_audit_watch_rule "augenrules" "/etc/passwd" "wa" "audit_rules_usergroup_modification"
# Function to fix audit file system object watch rule for given path:
# * if rule exists, also verifies the -w bits match the requirements
# * if rule doesn't exist yet, appends expected rule form to $files_to_inspect
#   audit rules file, depending on the tool which was used to load audit rules
#
# Expects four arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules'
# * path                        	value of -w audit rule's argument
# * required access bits        	value of -p audit rule's argument
# * key                         	value of -k audit rule's argument
#
# Example call:
#
#       fix_audit_watch_rule "auditctl" "/etc/localtime" "wa" "audit_time_rules"
#
function fix_audit_watch_rule {

# Load function arguments into local variables
local tool="$1"
local path="$2"
local required_access_bits="$3"
local key="$4"

# Check sanity of the input
if [ $# -ne "4" ]
then
	echo "Usage: fix_audit_watch_rule 'tool' 'path' 'bits' 'key'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
#
# -----------------------------------------------------------------------------------------
# Tool used to load audit rules	| Rule already defined	|  Audit rules file to inspect	  |
# -----------------------------------------------------------------------------------------
#	auditctl		|     Doesn't matter	|  /etc/audit/audit.rules	  |
# -----------------------------------------------------------------------------------------
# 	augenrules		|          Yes		|  /etc/audit/rules.d/*.rules	  |
# 	augenrules		|          No		|  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
declare -a files_to_inspect
files_to_inspect=()

# Check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	exit 1
# If the audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# into the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules')
# If the audit is 'augenrules', then check if rule is already defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to list of files for inspection.
# If rule isn't defined, add '/etc/audit/rules.d/$key.rules' to list of files for inspection.
elif [ "$tool" == 'augenrules' ]
then
	readarray -t matches < <(grep -P "[\s]*-w[\s]+$path" /etc/audit/rules.d/*.rules)

	# For each of the matched entries
	for match in "${matches[@]}"
	do
		# Extract filepath from the match
		rulesd_audit_file=$(echo $match | cut -f1 -d ':')
		# Append that path into list of files for inspection
		files_to_inspect+=("$rulesd_audit_file")
	done
	# Case when particular audit rule isn't defined yet
	if [ "${#files_to_inspect[@]}" -eq "0" ]
	then
		# Append '/etc/audit/rules.d/$key.rules' into list of files for inspection
		local key_rule_file="/etc/audit/rules.d/$key.rules"
		# If the $key.rules file doesn't exist yet, create it with correct permissions
		if [ ! -e "$key_rule_file" ]
		then
			touch "$key_rule_file"
			chmod 0640 "$key_rule_file"
		fi

		files_to_inspect+=("$key_rule_file")
	fi
fi

# Finally perform the inspection and possible subsequent audit rule
# correction for each of the files previously identified for inspection
for audit_rules_file in "${files_to_inspect[@]}"
do

	# Check if audit watch file system object rule for given path already present
	if grep -q -P -- "[\s]*-w[\s]+$path" "$audit_rules_file"
	then
		# Rule is found => verify yet if existing rule definition contains
		# all of the required access type bits

		# Escape slashes in path for use in sed pattern below
		local esc_path=${path//$'/'/$'\/'}
		# Define BRE whitespace class shortcut
		local sp="[[:space:]]"
		# Extract current permission access types (e.g. -p [r|w|x|a] values) from audit rule
		current_access_bits=$(sed -ne "s/$sp*-w$sp\+$esc_path$sp\+-p$sp\+\([rxwa]\{1,4\}\).*/\1/p" "$audit_rules_file")
		# Split required access bits string into characters array
		# (to check bit's presence for one bit at a time)
		for access_bit in $(echo "$required_access_bits" | grep -o .)
		do
			# For each from the required access bits (e.g. 'w', 'a') check
			# if they are already present in current access bits for rule.
			# If not, append that bit at the end
			if ! grep -q "$access_bit" <<< "$current_access_bits"
			then
				# Concatenate the existing mask with the missing bit
				current_access_bits="$current_access_bits$access_bit"
			fi
		done
		# Propagate the updated rule's access bits (original + the required
		# ones) back into the /etc/audit/audit.rules file for that rule
		sed -i "s/\($sp*-w$sp\+$esc_path$sp\+-p$sp\+\)\([rxwa]\{1,4\}\)\(.*\)/\1$current_access_bits\3/" "$audit_rules_file"
	else
		# Rule isn't present yet. Append it at the end of $audit_rules_file file
		# with proper key

		echo "-w $path -p $required_access_bits -k $key" >> "$audit_rules_file"
	fi
done
}
fix_audit_watch_rule "auditctl" "/etc/gshadow" "wa" "audit_rules_usergroup_modification"
fix_audit_watch_rule "augenrules" "/etc/gshadow" "wa" "audit_rules_usergroup_modification"
# Function to fix audit file system object watch rule for given path:
# * if rule exists, also verifies the -w bits match the requirements
# * if rule doesn't exist yet, appends expected rule form to $files_to_inspect
#   audit rules file, depending on the tool which was used to load audit rules
#
# Expects four arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules'
# * path                        	value of -w audit rule's argument
# * required access bits        	value of -p audit rule's argument
# * key                         	value of -k audit rule's argument
#
# Example call:
#
#       fix_audit_watch_rule "auditctl" "/etc/localtime" "wa" "audit_time_rules"
#
function fix_audit_watch_rule {

# Load function arguments into local variables
local tool="$1"
local path="$2"
local required_access_bits="$3"
local key="$4"

# Check sanity of the input
if [ $# -ne "4" ]
then
	echo "Usage: fix_audit_watch_rule 'tool' 'path' 'bits' 'key'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
#
# -----------------------------------------------------------------------------------------
# Tool used to load audit rules	| Rule already defined	|  Audit rules file to inspect	  |
# -----------------------------------------------------------------------------------------
#	auditctl		|     Doesn't matter	|  /etc/audit/audit.rules	  |
# -----------------------------------------------------------------------------------------
# 	augenrules		|          Yes		|  /etc/audit/rules.d/*.rules	  |
# 	augenrules		|          No		|  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
declare -a files_to_inspect
files_to_inspect=()

# Check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	exit 1
# If the audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# into the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules')
# If the audit is 'augenrules', then check if rule is already defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to list of files for inspection.
# If rule isn't defined, add '/etc/audit/rules.d/$key.rules' to list of files for inspection.
elif [ "$tool" == 'augenrules' ]
then
	readarray -t matches < <(grep -P "[\s]*-w[\s]+$path" /etc/audit/rules.d/*.rules)

	# For each of the matched entries
	for match in "${matches[@]}"
	do
		# Extract filepath from the match
		rulesd_audit_file=$(echo $match | cut -f1 -d ':')
		# Append that path into list of files for inspection
		files_to_inspect+=("$rulesd_audit_file")
	done
	# Case when particular audit rule isn't defined yet
	if [ "${#files_to_inspect[@]}" -eq "0" ]
	then
		# Append '/etc/audit/rules.d/$key.rules' into list of files for inspection
		local key_rule_file="/etc/audit/rules.d/$key.rules"
		# If the $key.rules file doesn't exist yet, create it with correct permissions
		if [ ! -e "$key_rule_file" ]
		then
			touch "$key_rule_file"
			chmod 0640 "$key_rule_file"
		fi

		files_to_inspect+=("$key_rule_file")
	fi
fi

# Finally perform the inspection and possible subsequent audit rule
# correction for each of the files previously identified for inspection
for audit_rules_file in "${files_to_inspect[@]}"
do

	# Check if audit watch file system object rule for given path already present
	if grep -q -P -- "[\s]*-w[\s]+$path" "$audit_rules_file"
	then
		# Rule is found => verify yet if existing rule definition contains
		# all of the required access type bits

		# Escape slashes in path for use in sed pattern below
		local esc_path=${path//$'/'/$'\/'}
		# Define BRE whitespace class shortcut
		local sp="[[:space:]]"
		# Extract current permission access types (e.g. -p [r|w|x|a] values) from audit rule
		current_access_bits=$(sed -ne "s/$sp*-w$sp\+$esc_path$sp\+-p$sp\+\([rxwa]\{1,4\}\).*/\1/p" "$audit_rules_file")
		# Split required access bits string into characters array
		# (to check bit's presence for one bit at a time)
		for access_bit in $(echo "$required_access_bits" | grep -o .)
		do
			# For each from the required access bits (e.g. 'w', 'a') check
			# if they are already present in current access bits for rule.
			# If not, append that bit at the end
			if ! grep -q "$access_bit" <<< "$current_access_bits"
			then
				# Concatenate the existing mask with the missing bit
				current_access_bits="$current_access_bits$access_bit"
			fi
		done
		# Propagate the updated rule's access bits (original + the required
		# ones) back into the /etc/audit/audit.rules file for that rule
		sed -i "s/\($sp*-w$sp\+$esc_path$sp\+-p$sp\+\)\([rxwa]\{1,4\}\)\(.*\)/\1$current_access_bits\3/" "$audit_rules_file"
	else
		# Rule isn't present yet. Append it at the end of $audit_rules_file file
		# with proper key

		echo "-w $path -p $required_access_bits -k $key" >> "$audit_rules_file"
	fi
done
}
fix_audit_watch_rule "auditctl" "/etc/shadow" "wa" "audit_rules_usergroup_modification"
fix_audit_watch_rule "augenrules" "/etc/shadow" "wa" "audit_rules_usergroup_modification"
# Function to fix audit file system object watch rule for given path:
# * if rule exists, also verifies the -w bits match the requirements
# * if rule doesn't exist yet, appends expected rule form to $files_to_inspect
#   audit rules file, depending on the tool which was used to load audit rules
#
# Expects four arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules'
# * path                        	value of -w audit rule's argument
# * required access bits        	value of -p audit rule's argument
# * key                         	value of -k audit rule's argument
#
# Example call:
#
#       fix_audit_watch_rule "auditctl" "/etc/localtime" "wa" "audit_time_rules"
#
function fix_audit_watch_rule {

# Load function arguments into local variables
local tool="$1"
local path="$2"
local required_access_bits="$3"
local key="$4"

# Check sanity of the input
if [ $# -ne "4" ]
then
	echo "Usage: fix_audit_watch_rule 'tool' 'path' 'bits' 'key'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
#
# -----------------------------------------------------------------------------------------
# Tool used to load audit rules	| Rule already defined	|  Audit rules file to inspect	  |
# -----------------------------------------------------------------------------------------
#	auditctl		|     Doesn't matter	|  /etc/audit/audit.rules	  |
# -----------------------------------------------------------------------------------------
# 	augenrules		|          Yes		|  /etc/audit/rules.d/*.rules	  |
# 	augenrules		|          No		|  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
declare -a files_to_inspect
files_to_inspect=()

# Check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	exit 1
# If the audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# into the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules')
# If the audit is 'augenrules', then check if rule is already defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to list of files for inspection.
# If rule isn't defined, add '/etc/audit/rules.d/$key.rules' to list of files for inspection.
elif [ "$tool" == 'augenrules' ]
then
	readarray -t matches < <(grep -P "[\s]*-w[\s]+$path" /etc/audit/rules.d/*.rules)

	# For each of the matched entries
	for match in "${matches[@]}"
	do
		# Extract filepath from the match
		rulesd_audit_file=$(echo $match | cut -f1 -d ':')
		# Append that path into list of files for inspection
		files_to_inspect+=("$rulesd_audit_file")
	done
	# Case when particular audit rule isn't defined yet
	if [ "${#files_to_inspect[@]}" -eq "0" ]
	then
		# Append '/etc/audit/rules.d/$key.rules' into list of files for inspection
		local key_rule_file="/etc/audit/rules.d/$key.rules"
		# If the $key.rules file doesn't exist yet, create it with correct permissions
		if [ ! -e "$key_rule_file" ]
		then
			touch "$key_rule_file"
			chmod 0640 "$key_rule_file"
		fi

		files_to_inspect+=("$key_rule_file")
	fi
fi

# Finally perform the inspection and possible subsequent audit rule
# correction for each of the files previously identified for inspection
for audit_rules_file in "${files_to_inspect[@]}"
do

	# Check if audit watch file system object rule for given path already present
	if grep -q -P -- "[\s]*-w[\s]+$path" "$audit_rules_file"
	then
		# Rule is found => verify yet if existing rule definition contains
		# all of the required access type bits

		# Escape slashes in path for use in sed pattern below
		local esc_path=${path//$'/'/$'\/'}
		# Define BRE whitespace class shortcut
		local sp="[[:space:]]"
		# Extract current permission access types (e.g. -p [r|w|x|a] values) from audit rule
		current_access_bits=$(sed -ne "s/$sp*-w$sp\+$esc_path$sp\+-p$sp\+\([rxwa]\{1,4\}\).*/\1/p" "$audit_rules_file")
		# Split required access bits string into characters array
		# (to check bit's presence for one bit at a time)
		for access_bit in $(echo "$required_access_bits" | grep -o .)
		do
			# For each from the required access bits (e.g. 'w', 'a') check
			# if they are already present in current access bits for rule.
			# If not, append that bit at the end
			if ! grep -q "$access_bit" <<< "$current_access_bits"
			then
				# Concatenate the existing mask with the missing bit
				current_access_bits="$current_access_bits$access_bit"
			fi
		done
		# Propagate the updated rule's access bits (original + the required
		# ones) back into the /etc/audit/audit.rules file for that rule
		sed -i "s/\($sp*-w$sp\+$esc_path$sp\+-p$sp\+\)\([rxwa]\{1,4\}\)\(.*\)/\1$current_access_bits\3/" "$audit_rules_file"
	else
		# Rule isn't present yet. Append it at the end of $audit_rules_file file
		# with proper key

		echo "-w $path -p $required_access_bits -k $key" >> "$audit_rules_file"
	fi
done
}
fix_audit_watch_rule "auditctl" "/etc/security/opasswd" "wa" "audit_rules_usergroup_modification"
fix_audit_watch_rule "augenrules" "/etc/security/opasswd" "wa" "audit_rules_usergroup_modification"

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_usergroup_modification'

###############################################################################
# BEGIN fix (63 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_mac_modification'
###############################################################################
(>&2 echo "Remediating rule 63/114: 'xccdf_org.ssgproject.content_rule_audit_rules_mac_modification'")


# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix audit file system object watch rule for given path:
# * if rule exists, also verifies the -w bits match the requirements
# * if rule doesn't exist yet, appends expected rule form to $files_to_inspect
#   audit rules file, depending on the tool which was used to load audit rules
#
# Expects four arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules'
# * path                        	value of -w audit rule's argument
# * required access bits        	value of -p audit rule's argument
# * key                         	value of -k audit rule's argument
#
# Example call:
#
#       fix_audit_watch_rule "auditctl" "/etc/localtime" "wa" "audit_time_rules"
#
function fix_audit_watch_rule {

# Load function arguments into local variables
local tool="$1"
local path="$2"
local required_access_bits="$3"
local key="$4"

# Check sanity of the input
if [ $# -ne "4" ]
then
	echo "Usage: fix_audit_watch_rule 'tool' 'path' 'bits' 'key'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
#
# -----------------------------------------------------------------------------------------
# Tool used to load audit rules	| Rule already defined	|  Audit rules file to inspect	  |
# -----------------------------------------------------------------------------------------
#	auditctl		|     Doesn't matter	|  /etc/audit/audit.rules	  |
# -----------------------------------------------------------------------------------------
# 	augenrules		|          Yes		|  /etc/audit/rules.d/*.rules	  |
# 	augenrules		|          No		|  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
declare -a files_to_inspect
files_to_inspect=()

# Check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	exit 1
# If the audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# into the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules')
# If the audit is 'augenrules', then check if rule is already defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to list of files for inspection.
# If rule isn't defined, add '/etc/audit/rules.d/$key.rules' to list of files for inspection.
elif [ "$tool" == 'augenrules' ]
then
	readarray -t matches < <(grep -P "[\s]*-w[\s]+$path" /etc/audit/rules.d/*.rules)

	# For each of the matched entries
	for match in "${matches[@]}"
	do
		# Extract filepath from the match
		rulesd_audit_file=$(echo $match | cut -f1 -d ':')
		# Append that path into list of files for inspection
		files_to_inspect+=("$rulesd_audit_file")
	done
	# Case when particular audit rule isn't defined yet
	if [ "${#files_to_inspect[@]}" -eq "0" ]
	then
		# Append '/etc/audit/rules.d/$key.rules' into list of files for inspection
		local key_rule_file="/etc/audit/rules.d/$key.rules"
		# If the $key.rules file doesn't exist yet, create it with correct permissions
		if [ ! -e "$key_rule_file" ]
		then
			touch "$key_rule_file"
			chmod 0640 "$key_rule_file"
		fi

		files_to_inspect+=("$key_rule_file")
	fi
fi

# Finally perform the inspection and possible subsequent audit rule
# correction for each of the files previously identified for inspection
for audit_rules_file in "${files_to_inspect[@]}"
do

	# Check if audit watch file system object rule for given path already present
	if grep -q -P -- "[\s]*-w[\s]+$path" "$audit_rules_file"
	then
		# Rule is found => verify yet if existing rule definition contains
		# all of the required access type bits

		# Escape slashes in path for use in sed pattern below
		local esc_path=${path//$'/'/$'\/'}
		# Define BRE whitespace class shortcut
		local sp="[[:space:]]"
		# Extract current permission access types (e.g. -p [r|w|x|a] values) from audit rule
		current_access_bits=$(sed -ne "s/$sp*-w$sp\+$esc_path$sp\+-p$sp\+\([rxwa]\{1,4\}\).*/\1/p" "$audit_rules_file")
		# Split required access bits string into characters array
		# (to check bit's presence for one bit at a time)
		for access_bit in $(echo "$required_access_bits" | grep -o .)
		do
			# For each from the required access bits (e.g. 'w', 'a') check
			# if they are already present in current access bits for rule.
			# If not, append that bit at the end
			if ! grep -q "$access_bit" <<< "$current_access_bits"
			then
				# Concatenate the existing mask with the missing bit
				current_access_bits="$current_access_bits$access_bit"
			fi
		done
		# Propagate the updated rule's access bits (original + the required
		# ones) back into the /etc/audit/audit.rules file for that rule
		sed -i "s/\($sp*-w$sp\+$esc_path$sp\+-p$sp\+\)\([rxwa]\{1,4\}\)\(.*\)/\1$current_access_bits\3/" "$audit_rules_file"
	else
		# Rule isn't present yet. Append it at the end of $audit_rules_file file
		# with proper key

		echo "-w $path -p $required_access_bits -k $key" >> "$audit_rules_file"
	fi
done
}
fix_audit_watch_rule "auditctl" "/etc/selinux/" "wa" "MAC-policy"
fix_audit_watch_rule "augenrules" "/etc/selinux/" "wa" "MAC-policy"

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_mac_modification'

###############################################################################
# BEGIN fix (64 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_media_export'
###############################################################################
(>&2 echo "Remediating rule 64/114: 'xccdf_org.ssgproject.content_rule_audit_rules_media_export'")


# Perform the remediation of the syscall rule
# Retrieve hardware architecture of the underlying system
[ "$(getconf LONG_BIT)" = "32" ] && RULE_ARCHS=("b32") || RULE_ARCHS=("b32" "b64")

for ARCH in "${RULE_ARCHS[@]}"
do
	PATTERN="-a always,exit -F arch=$ARCH -S .* -F auid>=500 -F auid!=unset -k *"
	GROUP="mount"
	FULL_RULE="-a always,exit -F arch=$ARCH -S mount -F auid>=500 -F auid!=unset -k export"
	# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}
	fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
	fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
done

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_media_export'

###############################################################################
# BEGIN fix (65 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_file_deletion_events'
###############################################################################
(>&2 echo "Remediating rule 65/114: 'xccdf_org.ssgproject.content_rule_audit_rules_file_deletion_events'")


# Perform the remediation for the syscall rule
# Retrieve hardware architecture of the underlying system
[ "$(getconf LONG_BIT)" = "32" ] && RULE_ARCHS=("b32") || RULE_ARCHS=("b32" "b64")

for ARCH in "${RULE_ARCHS[@]}"
do
	PATTERN="-a always,exit -F arch=$ARCH -S .* -F auid>=500 -F auid!=unset -k *"
	# Use escaped BRE regex to specify rule group
	GROUP="\(rmdir\|unlink\|rename\)"
	FULL_RULE="-a always,exit -F arch=$ARCH -S rmdir -S unlink -S unlinkat -S rename -S renameat -F auid>=500 -F auid!=unset -k delete"
	# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}
	fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
	fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
done

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_file_deletion_events'

###############################################################################
# BEGIN fix (66 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_privileged_commands'
###############################################################################
(>&2 echo "Remediating rule 66/114: 'xccdf_org.ssgproject.content_rule_audit_rules_privileged_commands'")


# Perform the remediation
# Function to perform remediation for 'audit_rules_privileged_commands' rule
#
# Expects two arguments:
#
# audit_tool		tool used to load audit rules
# 			One of 'auditctl' or 'augenrules'
#
# min_auid		Minimum original ID the user logged in with
# 			'500' for RHEL-6 and before, '1000' for RHEL-7 and after.
#
# Example Call(s):
#
#      perform_audit_rules_privileged_commands_remediation "auditctl" "500"
#      perform_audit_rules_privileged_commands_remediation "augenrules"	"1000"
#
function perform_audit_rules_privileged_commands_remediation {
#
# Load function arguments into local variables
local tool="$1"
local min_auid="$2"

# Check sanity of the input
if [ $# -ne "2" ]
then
	echo "Usage: perform_audit_rules_privileged_commands_remediation 'auditctl | augenrules' '500 | 1000'"
	echo "Aborting."
	exit 1
fi

declare -a files_to_inspect=()

# Check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	exit 1
# If the audit tool is 'auditctl', then:
# * add '/etc/audit/audit.rules'to the list of files to be inspected,
# * specify '/etc/audit/audit.rules' as the output audit file, where
#   missing rules should be inserted
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect=("/etc/audit/audit.rules")
	output_audit_file="/etc/audit/audit.rules"
#
# If the audit tool is 'augenrules', then:
# * add '/etc/audit/rules.d/*.rules' to the list of files to be inspected
#   (split by newline),
# * specify /etc/audit/rules.d/privileged.rules' as the output file, where
#   missing rules should be inserted
elif [ "$tool" == 'augenrules' ]
then
	readarray -t files_to_inspect < <(find /etc/audit/rules.d -maxdepth 1 -type f -name '*.rules' -print)
	output_audit_file="/etc/audit/rules.d/privileged.rules"
fi

# Obtain the list of SUID/SGID binaries on the particular system (split by newline)
# into privileged_binaries array
readarray -t privileged_binaries < <(find / -xdev -type f -perm -4000 -o -type f -perm -2000 2>/dev/null)

# Keep list of SUID/SGID binaries that have been already handled within some previous iteration
declare -a sbinaries_to_skip=()

# For each found sbinary in privileged_binaries list
for sbinary in "${privileged_binaries[@]}"
do

	# Check if this sbinary wasn't already handled in some of the previous sbinary iterations
	# Return match only if whole sbinary definition matched (not in the case just prefix matched!!!)
	if [[ $(sed -ne "\|${sbinary}|p" <<< "${sbinaries_to_skip[*]}") ]]
	then
		# If so, don't process it second time & go to process next sbinary
		continue
	fi

	# Reset the counter of inspected files when starting to check
	# presence of existing audit rule for new sbinary
	local count_of_inspected_files=0

	# Define expected rule form for this binary
	expected_rule="-a always,exit -F path=${sbinary} -F perm=x -F auid>=${min_auid} -F auid!=unset -k privileged"

	# If list of audit rules files to be inspected is empty, just add new rule and move on to next binary
	if [[ ${#files_to_inspect[@]} -eq 0 ]]; then
		echo "$expected_rule" >> "$output_audit_file"
		continue
	fi

	# Replace possible slash '/' character in sbinary definition so we could use it in sed expressions below
	sbinary_esc=${sbinary//$'/'/$'\/'}

	# For each audit rules file from the list of files to be inspected
	for afile in "${files_to_inspect[@]}"
	do

		# Search current audit rules file's content for match. Match criteria:
		# * existing rule is for the same SUID/SGID binary we are currently processing (but
		#   can contain multiple -F path= elements covering multiple SUID/SGID binaries)
		# * existing rule contains all arguments from expected rule form (though can contain
		#   them in arbitrary order)
	
		base_search=$(sed -e '/-a always,exit/!d' -e '/-F path='"${sbinary_esc}"'/!d'		\
				-e '/-F path=[^[:space:]]\+/!d'   -e '/-F perm=.*/!d'						\
				-e '/-F auid>='"${min_auid}"'/!d' -e '/-F auid!=\(4294967295\|unset\)/!d'	\
				-e '/-k \|-F key=/!d' "$afile")

		# Increase the count of inspected files for this sbinary
		count_of_inspected_files=$((count_of_inspected_files + 1))

		# Require execute access type to be set for existing audit rule
		exec_access='x'

		# Search current audit rules file's content for presence of rule pattern for this sbinary
		if [[ $base_search ]]
		then

			# Current audit rules file already contains rule for this binary =>
			# Store the exact form of found rule for this binary for further processing
			concrete_rule=$base_search

			# Select all other SUID/SGID binaries possibly also present in the found rule

			readarray -t handled_sbinaries < <(grep -o -e "-F path=[^[:space:]]\+" <<< "$concrete_rule")
			handled_sbinaries=("${handled_sbinaries[@]//-F path=/}")

			# Merge the list of such SUID/SGID binaries found in this iteration with global list ignoring duplicates
			readarray -t sbinaries_to_skip < <(for i in "${sbinaries_to_skip[@]}" "${handled_sbinaries[@]}"; do echo "$i"; done | sort -du)

			# Separate concrete_rule into three sections using hash '#'
			# sign as a delimiter around rule's permission section borders
			concrete_rule="$(echo "$concrete_rule" | sed -n "s/\(.*\)\+\(-F perm=[rwax]\+\)\+/\1#\2#/p")"

			# Split concrete_rule into head, perm, and tail sections using hash '#' delimiter

			rule_head=$(cut -d '#' -f 1 <<< "$concrete_rule")
			rule_perm=$(cut -d '#' -f 2 <<< "$concrete_rule")
			rule_tail=$(cut -d '#' -f 3 <<< "$concrete_rule")

			# Extract already present exact access type [r|w|x|a] from rule's permission section
			access_type=${rule_perm//-F perm=/}

			# Verify current permission access type(s) for rule contain 'x' (execute) permission
			if ! grep -q "$exec_access" <<< "$access_type"
			then

				# If not, append the 'x' (execute) permission to the existing access type bits
				access_type="$access_type$exec_access"
				# Reconstruct the permissions section for the rule
				new_rule_perm="-F perm=$access_type"
				# Update existing rule in current audit rules file with the new permission section
				sed -i "s#${rule_head}\(.*\)${rule_tail}#${rule_head}${new_rule_perm}${rule_tail}#" "$afile"

			fi

		# If the required audit rule for particular sbinary wasn't found yet, insert it under following conditions:
		#
		# * in the "auditctl" mode of operation insert particular rule each time
		#   (because in this mode there's only one file -- /etc/audit/audit.rules to be inspected for presence of this rule),
		#
		# * in the "augenrules" mode of operation insert particular rule only once and only in case we have already
		#   searched all of the files from /etc/audit/rules.d/*.rules location (since that audit rule can be defined
		#   in any of those files and if not, we want it to be inserted only once into /etc/audit/rules.d/privileged.rules file)
		#
		elif [ "$tool" == "auditctl" ] || [[ "$tool" == "augenrules" && $count_of_inspected_files -eq "${#files_to_inspect[@]}" ]]
		then

			# Check if this sbinary wasn't already handled in some of the previous afile iterations
			# Return match only if whole sbinary definition matched (not in the case just prefix matched!!!)
			if [[ ! $(sed -ne "\|${sbinary}|p" <<< "${sbinaries_to_skip[*]}") ]]
			then
				# Current audit rules file's content doesn't contain expected rule for this
				# SUID/SGID binary yet => append it
				echo "$expected_rule" >> "$output_audit_file"
			fi

			continue
		fi

	done

done
}
perform_audit_rules_privileged_commands_remediation "auditctl" "500"
perform_audit_rules_privileged_commands_remediation "augenrules" "500"

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_privileged_commands'

###############################################################################
# BEGIN fix (67 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_unsuccessful_file_modification'
###############################################################################
(>&2 echo "Remediating rule 67/114: 'xccdf_org.ssgproject.content_rule_audit_rules_unsuccessful_file_modification'")


# Perform the remediation of the syscall rule
# Retrieve hardware architecture of the underlying system
[ "$(getconf LONG_BIT)" = "32" ] && RULE_ARCHS=("b32") || RULE_ARCHS=("b32" "b64")

for ARCH in "${RULE_ARCHS[@]}"
do

	# First fix the -EACCES requirement
	PATTERN="-a always,exit -F arch=$ARCH -S .* -F exit=-EACCES -F auid>=500 -F auid!=unset -k *"
	# Use escaped BRE regex to specify rule group
	GROUP="\(creat\|open\|truncate\)"
	FULL_RULE="-a always,exit -F arch=$ARCH -S creat -S open -S openat -S open_by_handle_at -S truncate -S ftruncate -F exit=-EACCES -F auid>=500 -F auid!=unset -k access"
	# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}
	fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
	fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"

	# Then fix the -EPERM requirement
	PATTERN="-a always,exit -F arch=$ARCH -S .* -F exit=-EPERM -F auid>=500 -F auid!=unset -k *"
	# No need to change content of $GROUP variable - it's the same as for -EACCES case above
	FULL_RULE="-a always,exit -F arch=$ARCH -S creat -S open -S openat -S open_by_handle_at -S truncate -S ftruncate -F exit=-EPERM -F auid>=500 -F auid!=unset -k access"
	# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}
	fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
	fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"

done

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_unsuccessful_file_modification'

###############################################################################
# BEGIN fix (68 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_kernel_module_loading'
###############################################################################
(>&2 echo "Remediating rule 68/114: 'xccdf_org.ssgproject.content_rule_audit_rules_kernel_module_loading'")


# First perform the remediation of the syscall rule
# Retrieve hardware architecture of the underlying system
# Note: 32-bit and 64-bit kernel syscall numbers not always line up =>
#       it's required on a 64-bit system to check also for the presence
#       of 32-bit's equivalent of the corresponding rule.
#       (See `man 7 audit.rules` for details )
[ "$(getconf LONG_BIT)" = "32" ] && RULE_ARCHS=("b32") || RULE_ARCHS=("b32" "b64")

for ARCH in "${RULE_ARCHS[@]}"
do
        GROUP="modules"

        PATTERN="-a always,exit -F arch=$ARCH -S init_module -S delete_module \(-F key=\|-k \).*"
        FULL_RULE="-a always,exit -F arch=$ARCH -S init_module -S delete_module -k modules"

        # Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}
        fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
        fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
done

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_kernel_module_loading'

###############################################################################
# BEGIN fix (69 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_time_stime'
###############################################################################
(>&2 echo "Remediating rule 69/114: 'xccdf_org.ssgproject.content_rule_audit_rules_time_stime'")
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}


# Function to perform remediation for the 'adjtimex', 'settimeofday', and 'stime' audit
# system calls on RHEL, Fedora or OL systems.
# Remediation performed for both possible tools: 'auditctl' and 'augenrules'.
#
# Note: 'stime' system call isn't known at 64-bit arch (see "$ ausyscall x86_64 stime" 's output)
# therefore excluded from the list of time group system calls to be audited on this arch
#
# Example Call:
#
#      perform_audit_adjtimex_settimeofday_stime_remediation
#
function perform_audit_adjtimex_settimeofday_stime_remediation {

# Retrieve hardware architecture of the underlying system
[ "$(getconf LONG_BIT)" = "32" ] && RULE_ARCHS=("b32") || RULE_ARCHS=("b32" "b64")

for ARCH in "${RULE_ARCHS[@]}"
do

	PATTERN="-a always,exit -F arch=${ARCH} -S .* -k *"
	# Create expected audit group and audit rule form for particular system call & architecture
	if [ ${ARCH} = "b32" ]
	then
		# stime system call is known at 32-bit arch (see e.g "$ ausyscall i386 stime" 's output)
		# so append it to the list of time group system calls to be audited
		GROUP="\(adjtimex\|settimeofday\|stime\)"
		FULL_RULE="-a always,exit -F arch=${ARCH} -S adjtimex -S settimeofday -S stime -k audit_time_rules"
	elif [ ${ARCH} = "b64" ]
	then
		# stime system call isn't known at 64-bit arch (see "$ ausyscall x86_64 stime" 's output)
		# therefore don't add it to the list of time group system calls to be audited
		GROUP="\(adjtimex\|settimeofday\)"
		FULL_RULE="-a always,exit -F arch=${ARCH} -S adjtimex -S settimeofday -k audit_time_rules"
	fi
	# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
	fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
	fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
done

}
perform_audit_adjtimex_settimeofday_stime_remediation

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_time_stime'

###############################################################################
# BEGIN fix (70 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_time_clock_settime'
###############################################################################
(>&2 echo "Remediating rule 70/114: 'xccdf_org.ssgproject.content_rule_audit_rules_time_clock_settime'")


# First perform the remediation of the syscall rule
# Retrieve hardware architecture of the underlying system
[ "$(getconf LONG_BIT)" = "32" ] && RULE_ARCHS=("b32") || RULE_ARCHS=("b32" "b64")

for ARCH in "${RULE_ARCHS[@]}"
do
	PATTERN="-a always,exit -F arch=$ARCH -S clock_settime -F a0=.* \(-F key=\|-k \).*"
	GROUP="clock_settime"
	FULL_RULE="-a always,exit -F arch=$ARCH -S clock_settime -F a0=0x0 -k time-change"
	# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}
	fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
	fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
done

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_time_clock_settime'

###############################################################################
# BEGIN fix (71 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_time_settimeofday'
###############################################################################
(>&2 echo "Remediating rule 71/114: 'xccdf_org.ssgproject.content_rule_audit_rules_time_settimeofday'")
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}


# Function to perform remediation for the 'adjtimex', 'settimeofday', and 'stime' audit
# system calls on RHEL, Fedora or OL systems.
# Remediation performed for both possible tools: 'auditctl' and 'augenrules'.
#
# Note: 'stime' system call isn't known at 64-bit arch (see "$ ausyscall x86_64 stime" 's output)
# therefore excluded from the list of time group system calls to be audited on this arch
#
# Example Call:
#
#      perform_audit_adjtimex_settimeofday_stime_remediation
#
function perform_audit_adjtimex_settimeofday_stime_remediation {

# Retrieve hardware architecture of the underlying system
[ "$(getconf LONG_BIT)" = "32" ] && RULE_ARCHS=("b32") || RULE_ARCHS=("b32" "b64")

for ARCH in "${RULE_ARCHS[@]}"
do

	PATTERN="-a always,exit -F arch=${ARCH} -S .* -k *"
	# Create expected audit group and audit rule form for particular system call & architecture
	if [ ${ARCH} = "b32" ]
	then
		# stime system call is known at 32-bit arch (see e.g "$ ausyscall i386 stime" 's output)
		# so append it to the list of time group system calls to be audited
		GROUP="\(adjtimex\|settimeofday\|stime\)"
		FULL_RULE="-a always,exit -F arch=${ARCH} -S adjtimex -S settimeofday -S stime -k audit_time_rules"
	elif [ ${ARCH} = "b64" ]
	then
		# stime system call isn't known at 64-bit arch (see "$ ausyscall x86_64 stime" 's output)
		# therefore don't add it to the list of time group system calls to be audited
		GROUP="\(adjtimex\|settimeofday\)"
		FULL_RULE="-a always,exit -F arch=${ARCH} -S adjtimex -S settimeofday -k audit_time_rules"
	fi
	# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
	fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
	fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
done

}
perform_audit_adjtimex_settimeofday_stime_remediation

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_time_settimeofday'

###############################################################################
# BEGIN fix (72 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_time_adjtimex'
###############################################################################
(>&2 echo "Remediating rule 72/114: 'xccdf_org.ssgproject.content_rule_audit_rules_time_adjtimex'")
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}


# Function to perform remediation for the 'adjtimex', 'settimeofday', and 'stime' audit
# system calls on RHEL, Fedora or OL systems.
# Remediation performed for both possible tools: 'auditctl' and 'augenrules'.
#
# Note: 'stime' system call isn't known at 64-bit arch (see "$ ausyscall x86_64 stime" 's output)
# therefore excluded from the list of time group system calls to be audited on this arch
#
# Example Call:
#
#      perform_audit_adjtimex_settimeofday_stime_remediation
#
function perform_audit_adjtimex_settimeofday_stime_remediation {

# Retrieve hardware architecture of the underlying system
[ "$(getconf LONG_BIT)" = "32" ] && RULE_ARCHS=("b32") || RULE_ARCHS=("b32" "b64")

for ARCH in "${RULE_ARCHS[@]}"
do

	PATTERN="-a always,exit -F arch=${ARCH} -S .* -k *"
	# Create expected audit group and audit rule form for particular system call & architecture
	if [ ${ARCH} = "b32" ]
	then
		# stime system call is known at 32-bit arch (see e.g "$ ausyscall i386 stime" 's output)
		# so append it to the list of time group system calls to be audited
		GROUP="\(adjtimex\|settimeofday\|stime\)"
		FULL_RULE="-a always,exit -F arch=${ARCH} -S adjtimex -S settimeofday -S stime -k audit_time_rules"
	elif [ ${ARCH} = "b64" ]
	then
		# stime system call isn't known at 64-bit arch (see "$ ausyscall x86_64 stime" 's output)
		# therefore don't add it to the list of time group system calls to be audited
		GROUP="\(adjtimex\|settimeofday\)"
		FULL_RULE="-a always,exit -F arch=${ARCH} -S adjtimex -S settimeofday -k audit_time_rules"
	fi
	# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
	fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
	fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
done

}
perform_audit_adjtimex_settimeofday_stime_remediation

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_time_adjtimex'

###############################################################################
# BEGIN fix (73 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_time_watch_localtime'
###############################################################################
(>&2 echo "Remediating rule 73/114: 'xccdf_org.ssgproject.content_rule_audit_rules_time_watch_localtime'")


# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix audit file system object watch rule for given path:
# * if rule exists, also verifies the -w bits match the requirements
# * if rule doesn't exist yet, appends expected rule form to $files_to_inspect
#   audit rules file, depending on the tool which was used to load audit rules
#
# Expects four arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules'
# * path                        	value of -w audit rule's argument
# * required access bits        	value of -p audit rule's argument
# * key                         	value of -k audit rule's argument
#
# Example call:
#
#       fix_audit_watch_rule "auditctl" "/etc/localtime" "wa" "audit_time_rules"
#
function fix_audit_watch_rule {

# Load function arguments into local variables
local tool="$1"
local path="$2"
local required_access_bits="$3"
local key="$4"

# Check sanity of the input
if [ $# -ne "4" ]
then
	echo "Usage: fix_audit_watch_rule 'tool' 'path' 'bits' 'key'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
#
# -----------------------------------------------------------------------------------------
# Tool used to load audit rules	| Rule already defined	|  Audit rules file to inspect	  |
# -----------------------------------------------------------------------------------------
#	auditctl		|     Doesn't matter	|  /etc/audit/audit.rules	  |
# -----------------------------------------------------------------------------------------
# 	augenrules		|          Yes		|  /etc/audit/rules.d/*.rules	  |
# 	augenrules		|          No		|  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
declare -a files_to_inspect
files_to_inspect=()

# Check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	exit 1
# If the audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# into the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules')
# If the audit is 'augenrules', then check if rule is already defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to list of files for inspection.
# If rule isn't defined, add '/etc/audit/rules.d/$key.rules' to list of files for inspection.
elif [ "$tool" == 'augenrules' ]
then
	readarray -t matches < <(grep -P "[\s]*-w[\s]+$path" /etc/audit/rules.d/*.rules)

	# For each of the matched entries
	for match in "${matches[@]}"
	do
		# Extract filepath from the match
		rulesd_audit_file=$(echo $match | cut -f1 -d ':')
		# Append that path into list of files for inspection
		files_to_inspect+=("$rulesd_audit_file")
	done
	# Case when particular audit rule isn't defined yet
	if [ "${#files_to_inspect[@]}" -eq "0" ]
	then
		# Append '/etc/audit/rules.d/$key.rules' into list of files for inspection
		local key_rule_file="/etc/audit/rules.d/$key.rules"
		# If the $key.rules file doesn't exist yet, create it with correct permissions
		if [ ! -e "$key_rule_file" ]
		then
			touch "$key_rule_file"
			chmod 0640 "$key_rule_file"
		fi

		files_to_inspect+=("$key_rule_file")
	fi
fi

# Finally perform the inspection and possible subsequent audit rule
# correction for each of the files previously identified for inspection
for audit_rules_file in "${files_to_inspect[@]}"
do

	# Check if audit watch file system object rule for given path already present
	if grep -q -P -- "[\s]*-w[\s]+$path" "$audit_rules_file"
	then
		# Rule is found => verify yet if existing rule definition contains
		# all of the required access type bits

		# Escape slashes in path for use in sed pattern below
		local esc_path=${path//$'/'/$'\/'}
		# Define BRE whitespace class shortcut
		local sp="[[:space:]]"
		# Extract current permission access types (e.g. -p [r|w|x|a] values) from audit rule
		current_access_bits=$(sed -ne "s/$sp*-w$sp\+$esc_path$sp\+-p$sp\+\([rxwa]\{1,4\}\).*/\1/p" "$audit_rules_file")
		# Split required access bits string into characters array
		# (to check bit's presence for one bit at a time)
		for access_bit in $(echo "$required_access_bits" | grep -o .)
		do
			# For each from the required access bits (e.g. 'w', 'a') check
			# if they are already present in current access bits for rule.
			# If not, append that bit at the end
			if ! grep -q "$access_bit" <<< "$current_access_bits"
			then
				# Concatenate the existing mask with the missing bit
				current_access_bits="$current_access_bits$access_bit"
			fi
		done
		# Propagate the updated rule's access bits (original + the required
		# ones) back into the /etc/audit/audit.rules file for that rule
		sed -i "s/\($sp*-w$sp\+$esc_path$sp\+-p$sp\+\)\([rxwa]\{1,4\}\)\(.*\)/\1$current_access_bits\3/" "$audit_rules_file"
	else
		# Rule isn't present yet. Append it at the end of $audit_rules_file file
		# with proper key

		echo "-w $path -p $required_access_bits -k $key" >> "$audit_rules_file"
	fi
done
}
fix_audit_watch_rule "auditctl" "/etc/localtime" "wa" "audit_time_rules"
fix_audit_watch_rule "augenrules" "/etc/localtime" "wa" "audit_time_rules"

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_time_watch_localtime'

###############################################################################
# BEGIN fix (74 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_fchownat'
###############################################################################
(>&2 echo "Remediating rule 74/114: 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_fchownat'")


# First perform the remediation of the syscall rule
# Retrieve hardware architecture of the underlying system
[ "$(getconf LONG_BIT)" = "32" ] && RULE_ARCHS=("b32") || RULE_ARCHS=("b32" "b64")

for ARCH in "${RULE_ARCHS[@]}"
do
	PATTERN="-a always,exit -F arch=$ARCH -S fchownat.*"
	GROUP="perm_mod"
	FULL_RULE="-a always,exit -F arch=$ARCH -S fchownat -F auid>=500 -F auid!=unset -F key=perm_mod"

	# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}
	fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
	fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
done

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_fchownat'

###############################################################################
# BEGIN fix (75 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_fchmodat'
###############################################################################
(>&2 echo "Remediating rule 75/114: 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_fchmodat'")


# First perform the remediation of the syscall rule
# Retrieve hardware architecture of the underlying system
[ "$(getconf LONG_BIT)" = "32" ] && RULE_ARCHS=("b32") || RULE_ARCHS=("b32" "b64")

for ARCH in "${RULE_ARCHS[@]}"
do
	PATTERN="-a always,exit -F arch=$ARCH -S fchmodat.*"
	GROUP="perm_mod"
	FULL_RULE="-a always,exit -F arch=$ARCH -S fchmodat -F auid>=500 -F auid!=unset -F key=perm_mod"

	# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}
	fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
	fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
done

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_fchmodat'

###############################################################################
# BEGIN fix (76 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_lsetxattr'
###############################################################################
(>&2 echo "Remediating rule 76/114: 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_lsetxattr'")


# First perform the remediation of the syscall rule
# Retrieve hardware architecture of the underlying system
[ "$(getconf LONG_BIT)" = "32" ] && RULE_ARCHS=("b32") || RULE_ARCHS=("b32" "b64")

for ARCH in "${RULE_ARCHS[@]}"
do
	PATTERN="-a always,exit -F arch=$ARCH -S lsetxattr.*"
	GROUP="perm_mod"
	FULL_RULE="-a always,exit -F arch=$ARCH -S lsetxattr -F auid>=500 -F auid!=unset -F key=perm_mod"

	# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}
	fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
	fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
done

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_lsetxattr'

###############################################################################
# BEGIN fix (77 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_chmod'
###############################################################################
(>&2 echo "Remediating rule 77/114: 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_chmod'")


# First perform the remediation of the syscall rule
# Retrieve hardware architecture of the underlying system
[ "$(getconf LONG_BIT)" = "32" ] && RULE_ARCHS=("b32") || RULE_ARCHS=("b32" "b64")

for ARCH in "${RULE_ARCHS[@]}"
do
	PATTERN="-a always,exit -F arch=$ARCH -S chmod.*"
	GROUP="perm_mod"
	FULL_RULE="-a always,exit -F arch=$ARCH -S chmod -F auid>=500 -F auid!=unset -F key=perm_mod"

	# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}
	fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
	fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
done

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_chmod'

###############################################################################
# BEGIN fix (78 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_fchmod'
###############################################################################
(>&2 echo "Remediating rule 78/114: 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_fchmod'")


# First perform the remediation of the syscall rule
# Retrieve hardware architecture of the underlying system
[ "$(getconf LONG_BIT)" = "32" ] && RULE_ARCHS=("b32") || RULE_ARCHS=("b32" "b64")

for ARCH in "${RULE_ARCHS[@]}"
do
	PATTERN="-a always,exit -F arch=$ARCH -S fchmod.*"
	GROUP="perm_mod"
	FULL_RULE="-a always,exit -F arch=$ARCH -S fchmod -F auid>=500 -F auid!=unset -F key=perm_mod"

	# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}
	fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
	fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
done

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_fchmod'

###############################################################################
# BEGIN fix (79 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_lremovexattr'
###############################################################################
(>&2 echo "Remediating rule 79/114: 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_lremovexattr'")


# First perform the remediation of the syscall rule
# Retrieve hardware architecture of the underlying system
[ "$(getconf LONG_BIT)" = "32" ] && RULE_ARCHS=("b32") || RULE_ARCHS=("b32" "b64")

for ARCH in "${RULE_ARCHS[@]}"
do
	PATTERN="-a always,exit -F arch=$ARCH -S lremovexattr.*"
	GROUP="perm_mod"
	FULL_RULE="-a always,exit -F arch=$ARCH -S lremovexattr -F auid>=500 -F auid!=unset -F key=perm_mod"

	# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}
	fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
	fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
done

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_lremovexattr'

###############################################################################
# BEGIN fix (80 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_lchown'
###############################################################################
(>&2 echo "Remediating rule 80/114: 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_lchown'")


# First perform the remediation of the syscall rule
# Retrieve hardware architecture of the underlying system
[ "$(getconf LONG_BIT)" = "32" ] && RULE_ARCHS=("b32") || RULE_ARCHS=("b32" "b64")

for ARCH in "${RULE_ARCHS[@]}"
do
	PATTERN="-a always,exit -F arch=$ARCH -S lchown.*"
	GROUP="perm_mod"
	FULL_RULE="-a always,exit -F arch=$ARCH -S lchown -F auid>=500 -F auid!=unset -F key=perm_mod"

	# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}
	fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
	fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
done

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_lchown'

###############################################################################
# BEGIN fix (81 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_setxattr'
###############################################################################
(>&2 echo "Remediating rule 81/114: 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_setxattr'")


# First perform the remediation of the syscall rule
# Retrieve hardware architecture of the underlying system
[ "$(getconf LONG_BIT)" = "32" ] && RULE_ARCHS=("b32") || RULE_ARCHS=("b32" "b64")

for ARCH in "${RULE_ARCHS[@]}"
do
	PATTERN="-a always,exit -F arch=$ARCH -S setxattr.*"
	GROUP="perm_mod"
	FULL_RULE="-a always,exit -F arch=$ARCH -S setxattr -F auid>=500 -F auid!=unset -F key=perm_mod"

	# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}
	fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
	fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
done

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_setxattr'

###############################################################################
# BEGIN fix (82 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_chown'
###############################################################################
(>&2 echo "Remediating rule 82/114: 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_chown'")


# First perform the remediation of the syscall rule
# Retrieve hardware architecture of the underlying system
[ "$(getconf LONG_BIT)" = "32" ] && RULE_ARCHS=("b32") || RULE_ARCHS=("b32" "b64")

for ARCH in "${RULE_ARCHS[@]}"
do
	PATTERN="-a always,exit -F arch=$ARCH -S chown.*"
	GROUP="perm_mod"
	FULL_RULE="-a always,exit -F arch=$ARCH -S chown -F auid>=500 -F auid!=unset -F key=perm_mod"

	# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}
	fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
	fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
done

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_chown'

###############################################################################
# BEGIN fix (83 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_removexattr'
###############################################################################
(>&2 echo "Remediating rule 83/114: 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_removexattr'")


# First perform the remediation of the syscall rule
# Retrieve hardware architecture of the underlying system
[ "$(getconf LONG_BIT)" = "32" ] && RULE_ARCHS=("b32") || RULE_ARCHS=("b32" "b64")

for ARCH in "${RULE_ARCHS[@]}"
do
	PATTERN="-a always,exit -F arch=$ARCH -S removexattr.*"
	GROUP="perm_mod"
	FULL_RULE="-a always,exit -F arch=$ARCH -S removexattr -F auid>=500 -F auid!=unset -F key=perm_mod"

	# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}
	fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
	fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
done

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_removexattr'

###############################################################################
# BEGIN fix (84 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_fchown'
###############################################################################
(>&2 echo "Remediating rule 84/114: 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_fchown'")


# First perform the remediation of the syscall rule
# Retrieve hardware architecture of the underlying system
[ "$(getconf LONG_BIT)" = "32" ] && RULE_ARCHS=("b32") || RULE_ARCHS=("b32" "b64")

for ARCH in "${RULE_ARCHS[@]}"
do
	PATTERN="-a always,exit -F arch=$ARCH -S fchown.*"
	GROUP="perm_mod"
	FULL_RULE="-a always,exit -F arch=$ARCH -S fchown -F auid>=500 -F auid!=unset -F key=perm_mod"

	# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}
	fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
	fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
done

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_fchown'

###############################################################################
# BEGIN fix (85 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_fremovexattr'
###############################################################################
(>&2 echo "Remediating rule 85/114: 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_fremovexattr'")


# First perform the remediation of the syscall rule
# Retrieve hardware architecture of the underlying system
[ "$(getconf LONG_BIT)" = "32" ] && RULE_ARCHS=("b32") || RULE_ARCHS=("b32" "b64")

for ARCH in "${RULE_ARCHS[@]}"
do
	PATTERN="-a always,exit -F arch=$ARCH -S fremovexattr.*"
	GROUP="perm_mod"
	FULL_RULE="-a always,exit -F arch=$ARCH -S fremovexattr -F auid>=500 -F auid!=unset -F key=perm_mod"

	# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}
	fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
	fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
done

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_fremovexattr'

###############################################################################
# BEGIN fix (86 / 114) for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_fsetxattr'
###############################################################################
(>&2 echo "Remediating rule 86/114: 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_fsetxattr'")


# First perform the remediation of the syscall rule
# Retrieve hardware architecture of the underlying system
[ "$(getconf LONG_BIT)" = "32" ] && RULE_ARCHS=("b32") || RULE_ARCHS=("b32" "b64")

for ARCH in "${RULE_ARCHS[@]}"
do
	PATTERN="-a always,exit -F arch=$ARCH -S fsetxattr.*"
	GROUP="perm_mod"
	FULL_RULE="-a always,exit -F arch=$ARCH -S fsetxattr -F auid>=500 -F auid!=unset -F key=perm_mod"

	# Perform the remediation for both possible tools: 'auditctl' and 'augenrules'
# Function to fix syscall audit rule for given system call. It is
# based on example audit syscall rule definitions as outlined in
# /usr/share/doc/audit-2.3.7/stig.rules file provided with the audit
# package. It will combine multiple system calls belonging to the same
# syscall group into one audit rule (rather than to create audit rule per
# different system call) to avoid audit infrastructure performance penalty
# in the case of 'one-audit-rule-definition-per-one-system-call'. See:
#
#   https://www.redhat.com/archives/linux-audit/2014-November/msg00009.html
#
# for further details.
#
# Expects five arguments (each of them is required) in the form of:
# * audit tool				tool used to load audit rules,
# 					either 'auditctl', or 'augenrules
# * audit rules' pattern		audit rule skeleton for same syscall
# * syscall group			greatest common string this rule shares
# 					with other rules from the same group
# * architecture			architecture this rule is intended for
# * full form of new rule to add	expected full form of audit rule as to be
# 					added into audit.rules file
#
# Note: The 2-th up to 4-th arguments are used to determine how many existing
# audit rules will be inspected for resemblance with the new audit rule
# (5-th argument) the function is going to add. The rule's similarity check
# is performed to optimize audit.rules definition (merge syscalls of the same
# group into one rule) to avoid the "single-syscall-per-audit-rule" performance
# penalty.
#
# Example call:
#
#	See e.g. 'audit_rules_file_deletion_events.sh' remediation script
#
function fix_audit_syscall_rule {

# Load function arguments into local variables
local tool="$1"
local pattern="$2"
local group="$3"
local arch="$4"
local full_rule="$5"

# Check sanity of the input
if [ $# -ne "5" ]
then
	echo "Usage: fix_audit_syscall_rule 'tool' 'pattern' 'group' 'arch' 'full rule'"
	echo "Aborting."
	exit 1
fi

# Create a list of audit *.rules files that should be inspected for presence and correctness
# of a particular audit rule. The scheme is as follows:
# 
# -----------------------------------------------------------------------------------------
#  Tool used to load audit rules | Rule already defined  |  Audit rules file to inspect    |
# -----------------------------------------------------------------------------------------
#        auditctl                |     Doesn't matter    |  /etc/audit/audit.rules         |
# -----------------------------------------------------------------------------------------
#        augenrules              |          Yes          |  /etc/audit/rules.d/*.rules     |
#        augenrules              |          No           |  /etc/audit/rules.d/$key.rules  |
# -----------------------------------------------------------------------------------------
#
declare -a files_to_inspect

retval=0

# First check sanity of the specified audit tool
if [ "$tool" != 'auditctl' ] && [ "$tool" != 'augenrules' ]
then
	echo "Unknown audit rules loading tool: $1. Aborting."
	echo "Use either 'auditctl' or 'augenrules'!"
	return 1
# If audit tool is 'auditctl', then add '/etc/audit/audit.rules'
# file to the list of files to be inspected
elif [ "$tool" == 'auditctl' ]
then
	files_to_inspect+=('/etc/audit/audit.rules' )
# If audit tool is 'augenrules', then check if the audit rule is defined
# If rule is defined, add '/etc/audit/rules.d/*.rules' to the list for inspection
# If rule isn't defined yet, add '/etc/audit/rules.d/$key.rules' to the list for inspection
elif [ "$tool" == 'augenrules' ]
then
	# Extract audit $key from audit rule so we can use it later
	key=$(expr "$full_rule" : '.*-k[[:space:]]\([^[:space:]]\+\)' '|' "$full_rule" : '.*-F[[:space:]]key=\([^[:space:]]\+\)')
	readarray -t matches < <(sed -s -n -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d;F" /etc/audit/rules.d/*.rules)
	if [ $? -ne 0 ]
	then
		retval=1
	fi
	for match in "${matches[@]}"
	do
		files_to_inspect+=("${match}")
	done
	# Case when particular rule isn't defined in /etc/audit/rules.d/*.rules yet
	if [ ${#files_to_inspect[@]} -eq "0" ]
	then
		file_to_inspect="/etc/audit/rules.d/$key.rules"
		files_to_inspect=("$file_to_inspect")
		if [ ! -e "$file_to_inspect" ]
		then
			touch "$file_to_inspect"
			chmod 0640 "$file_to_inspect"
		fi
	fi
fi

#
# Indicator that we want to append $full_rule into $audit_file by default
local append_expected_rule=0

for audit_file in "${files_to_inspect[@]}"
do
	# Filter existing $audit_file rules' definitions to select those that:
	# * follow the rule pattern, and
	# * meet the hardware architecture requirement, and
	# * are current syscall group specific
	readarray -t existing_rules < <(sed -e "\;${pattern};!d" -e "/${arch}/!d" -e "/${group}/!d"  "$audit_file")
	if [ $? -ne 0 ]
	then
		retval=1
	fi

	# Process rules found case-by-case
	for rule in "${existing_rules[@]}"
	do
		# Found rule is for same arch & key, but differs (e.g. in count of -S arguments)
		if [ "${rule}" != "${full_rule}" ]
		then
			# If so, isolate just '(-S \w)+' substring of that rule
			rule_syscalls=$(echo "$rule" | grep -o -P '(-S \w+ )+')
			# Check if list of '-S syscall' arguments of that rule is subset
			# of '-S syscall' list of expected $full_rule
			if grep -q -- "$rule_syscalls" <<< "$full_rule"
			then
				# Rule is covered (i.e. the list of -S syscalls for this rule is
				# subset of -S syscalls of $full_rule => existing rule can be deleted
				# Thus delete the rule from audit.rules & our array
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi
				existing_rules=("${existing_rules[@]//$rule/}")
			else
				# Rule isn't covered by $full_rule - it besides -S syscall arguments
				# for this group contains also -S syscall arguments for other syscall
				# group. Example: '-S lchown -S fchmod -S fchownat' => group='chown'
				# since 'lchown' & 'fchownat' share 'chown' substring
				# Therefore:
				# * 1) delete the original rule from audit.rules
				# (original '-S lchown -S fchmod -S fchownat' rule would be deleted)
				# * 2) delete the -S syscall arguments for this syscall group, but
				# keep those not belonging to this syscall group
				# (original '-S lchown -S fchmod -S fchownat' would become '-S fchmod'
				# * 3) append the modified (filtered) rule again into audit.rules
				# if the same rule not already present
				#
				# 1) Delete the original rule
				sed -i -e "\;${rule};d" "$audit_file"
				if [ $? -ne 0 ]
				then
					retval=1
				fi

				# 2) Delete syscalls for this group, but keep those from other groups
				# Convert current rule syscall's string into array splitting by '-S' delimiter
				IFS_BKP="$IFS"
				IFS=$'-S'
				read -a rule_syscalls_as_array <<< "$rule_syscalls"
				# Reset IFS back to default
				IFS="$IFS_BKP"
				# Splitting by "-S" can't be replaced by the readarray functionality easily

				# Declare new empty string to hold '-S syscall' arguments from other groups
				new_syscalls_for_rule=''
				# Walk through existing '-S syscall' arguments
				for syscall_arg in "${rule_syscalls_as_array[@]}"
				do
					# Skip empty $syscall_arg values
					if [ "$syscall_arg" == '' ]
					then
						continue
					fi
					# If the '-S syscall' doesn't belong to current group add it to the new list
					# (together with adding '-S' delimiter back for each of such item found)
					if grep -q -v -- "$group" <<< "$syscall_arg"
					then
						new_syscalls_for_rule="$new_syscalls_for_rule -S $syscall_arg"
					fi
				done
				# Replace original '-S syscall' list with the new one for this rule
				updated_rule=${rule//$rule_syscalls/$new_syscalls_for_rule}
				# Squeeze repeated whitespace characters in rule definition (if any) into one
				updated_rule=$(echo "$updated_rule" | tr -s '[:space:]')
				# 3) Append the modified / filtered rule again into audit.rules
				#    (but only in case it's not present yet to prevent duplicate definitions)
				if ! grep -q -- "$updated_rule" "$audit_file"
				then
					echo "$updated_rule" >> "$audit_file"
				fi
			fi
		else
			# $audit_file already contains the expected rule form for this
			# architecture & key => don't insert it second time
			append_expected_rule=1
		fi
	done

	# We deleted all rules that were subset of the expected one for this arch & key.
	# Also isolated rules containing system calls not from this system calls group.
	# Now append the expected rule if it's not present in $audit_file yet
	if [[ ${append_expected_rule} -eq "0" ]]
	then
		echo "$full_rule" >> "$audit_file"
	fi
done

return $retval

}
	fix_audit_syscall_rule "augenrules" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
	fix_audit_syscall_rule "auditctl" "$PATTERN" "$GROUP" "$ARCH" "$FULL_RULE"
done

# END fix for 'xccdf_org.ssgproject.content_rule_audit_rules_dac_modification_fsetxattr'

###############################################################################
# BEGIN fix (87 / 114) for 'xccdf_org.ssgproject.content_rule_auditd_data_retention_space_left'
###############################################################################
(>&2 echo "Remediating rule 87/114: 'xccdf_org.ssgproject.content_rule_auditd_data_retention_space_left'")

var_auditd_space_left="100"

grep -q "^space_left[[:space:]]*=.*$" /etc/audit/auditd.conf && \
  sed -i "s/^space_left[[:space:]]*=.*$/space_left = $var_auditd_space_left/g" /etc/audit/auditd.conf || \
  echo "space_left = $var_auditd_space_left" >> /etc/audit/auditd.conf

# END fix for 'xccdf_org.ssgproject.content_rule_auditd_data_retention_space_left'

###############################################################################
# BEGIN fix (88 / 114) for 'xccdf_org.ssgproject.content_rule_auditd_data_retention_space_left_action'
###############################################################################
(>&2 echo "Remediating rule 88/114: 'xccdf_org.ssgproject.content_rule_auditd_data_retention_space_left_action'")

var_auditd_space_left_action="email"

#
# If space_left_action present in /etc/audit/auditd.conf, change value
# to var_auditd_space_left_action, else
# add "space_left_action = $var_auditd_space_left_action" to /etc/audit/auditd.conf
#

AUDITCONFIG=/etc/audit/auditd.conf
# Function to replace configuration setting in config file or add the configuration setting if
# it does not exist.
#
# Expects arguments:
#
# config_file:		Configuration file that will be modified
# key:			Configuration option to change
# value:		Value of the configuration option to change
# cce:			The CCE identifier or '@CCENUM@' if no CCE identifier exists
# format:		The printf-like format string that will be given stripped key and value as arguments,
#			so e.g. '%s=%s' will result in key=value subsitution (i.e. without spaces around =)
#
# Optional arugments:
#
# format:		Optional argument to specify the format of how key/value should be
# 			modified/appended in the configuration file. The default is key = value.
#
# Example Call(s):
#
#     With default format of 'key = value':
#     replace_or_append '/etc/sysctl.conf' '^kernel.randomize_va_space' '2' '@CCENUM@'
#
#     With custom key/value format:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' 'disabled' '@CCENUM@' '%s=%s'
#
#     With a variable:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' $var_selinux_state '@CCENUM@' '%s=%s'
#
function replace_or_append {
  local default_format='%s = %s' case_insensitive_mode=yes sed_case_insensitive_option='' grep_case_insensitive_option=''
  local config_file=$1
  local key=$2
  local value=$3
  local cce=$4
  local format=$5

  if [ "$case_insensitive_mode" = yes ]; then
    sed_case_insensitive_option="i"
    grep_case_insensitive_option="-i"
  fi
  [ -n "$format" ] || format="$default_format"
  # Check sanity of the input
  [ $# -ge "3" ] || { echo "Usage: replace_or_append <config_file_location> <key_to_search> <new_value> [<CCE number or literal '@CCENUM@' if unknown>] [printf-like format, default is '$default_format']" >&2; exit 1; }

  # Test if the config_file is a symbolic link. If so, use --follow-symlinks with sed.
  # Otherwise, regular sed command will do.
  sed_command=('sed' '-i')
  if test -L "$config_file"; then
    sed_command+=('--follow-symlinks')
  fi

  # Test that the cce arg is not empty or does not equal @CCENUM@.
  # If @CCENUM@ exists, it means that there is no CCE assigned.
  if [ -n "$cce" ] && [ "$cce" != '@CCENUM@' ]; then
    cce="${cce}"
  else
    cce="CCE"
  fi

  # Strip any search characters in the key arg so that the key can be replaced without
  # adding any search characters to the config file.
  stripped_key=$(sed 's/[\^=\$,;+]*//g' <<< "$key")

  # shellcheck disable=SC2059
  printf -v formatted_output "$format" "$stripped_key" "$value"

  # If the key exists, change it. Otherwise, add it to the config_file.
  # We search for the key string followed by a word boundary (matched by \>),
  # so if we search for 'setting', 'setting2' won't match.
  if LC_ALL=C grep -q -m 1 $grep_case_insensitive_option -e "${key}\\>" "$config_file"; then
    "${sed_command[@]}" "s/${key}\\>.*/$formatted_output/g$sed_case_insensitive_option" "$config_file"
  else
    # \n is precaution for case where file ends without trailing newline
    printf '\n# Per %s: Set %s in %s\n' "$cce" "$formatted_output" "$config_file" >> "$config_file"
    printf '%s\n' "$formatted_output" >> "$config_file"
  fi
}
replace_or_append $AUDITCONFIG '^space_left_action' "$var_auditd_space_left_action" "CCE-27238-5"

# END fix for 'xccdf_org.ssgproject.content_rule_auditd_data_retention_space_left_action'

###############################################################################
# BEGIN fix (89 / 114) for 'xccdf_org.ssgproject.content_rule_auditd_data_disk_error_action'
###############################################################################
(>&2 echo "Remediating rule 89/114: 'xccdf_org.ssgproject.content_rule_auditd_data_disk_error_action'")

var_auditd_disk_error_action="single"

#
# If disk_error_action present in /etc/audit/auditd.conf, change value
# to var_auditd_disk_error_action, else
# add "disk_error_action = $var_auditd_disk_error_action" to /etc/audit/auditd.conf
#

if grep --silent ^disk_error_action /etc/audit/auditd.conf ; then
        sed -i 's/^disk_error_action.*/disk_error_action = '"$var_auditd_disk_error_action"'/g' /etc/audit/auditd.conf
else
        echo -e "\n# Set disk_error_action to $var_auditd_disk_error_action per security requirements" >> /etc/audit/auditd.conf
        echo "disk_error_action = $var_auditd_disk_error_action" >> /etc/audit/auditd.conf
fi

# END fix for 'xccdf_org.ssgproject.content_rule_auditd_data_disk_error_action'

###############################################################################
# BEGIN fix (90 / 114) for 'xccdf_org.ssgproject.content_rule_auditd_data_retention_admin_space_left_action'
###############################################################################
(>&2 echo "Remediating rule 90/114: 'xccdf_org.ssgproject.content_rule_auditd_data_retention_admin_space_left_action'")

var_auditd_admin_space_left_action="single"

AUDITCONFIG=/etc/audit/auditd.conf
# Function to replace configuration setting in config file or add the configuration setting if
# it does not exist.
#
# Expects arguments:
#
# config_file:		Configuration file that will be modified
# key:			Configuration option to change
# value:		Value of the configuration option to change
# cce:			The CCE identifier or '@CCENUM@' if no CCE identifier exists
# format:		The printf-like format string that will be given stripped key and value as arguments,
#			so e.g. '%s=%s' will result in key=value subsitution (i.e. without spaces around =)
#
# Optional arugments:
#
# format:		Optional argument to specify the format of how key/value should be
# 			modified/appended in the configuration file. The default is key = value.
#
# Example Call(s):
#
#     With default format of 'key = value':
#     replace_or_append '/etc/sysctl.conf' '^kernel.randomize_va_space' '2' '@CCENUM@'
#
#     With custom key/value format:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' 'disabled' '@CCENUM@' '%s=%s'
#
#     With a variable:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' $var_selinux_state '@CCENUM@' '%s=%s'
#
function replace_or_append {
  local default_format='%s = %s' case_insensitive_mode=yes sed_case_insensitive_option='' grep_case_insensitive_option=''
  local config_file=$1
  local key=$2
  local value=$3
  local cce=$4
  local format=$5

  if [ "$case_insensitive_mode" = yes ]; then
    sed_case_insensitive_option="i"
    grep_case_insensitive_option="-i"
  fi
  [ -n "$format" ] || format="$default_format"
  # Check sanity of the input
  [ $# -ge "3" ] || { echo "Usage: replace_or_append <config_file_location> <key_to_search> <new_value> [<CCE number or literal '@CCENUM@' if unknown>] [printf-like format, default is '$default_format']" >&2; exit 1; }

  # Test if the config_file is a symbolic link. If so, use --follow-symlinks with sed.
  # Otherwise, regular sed command will do.
  sed_command=('sed' '-i')
  if test -L "$config_file"; then
    sed_command+=('--follow-symlinks')
  fi

  # Test that the cce arg is not empty or does not equal @CCENUM@.
  # If @CCENUM@ exists, it means that there is no CCE assigned.
  if [ -n "$cce" ] && [ "$cce" != '@CCENUM@' ]; then
    cce="${cce}"
  else
    cce="CCE"
  fi

  # Strip any search characters in the key arg so that the key can be replaced without
  # adding any search characters to the config file.
  stripped_key=$(sed 's/[\^=\$,;+]*//g' <<< "$key")

  # shellcheck disable=SC2059
  printf -v formatted_output "$format" "$stripped_key" "$value"

  # If the key exists, change it. Otherwise, add it to the config_file.
  # We search for the key string followed by a word boundary (matched by \>),
  # so if we search for 'setting', 'setting2' won't match.
  if LC_ALL=C grep -q -m 1 $grep_case_insensitive_option -e "${key}\\>" "$config_file"; then
    "${sed_command[@]}" "s/${key}\\>.*/$formatted_output/g$sed_case_insensitive_option" "$config_file"
  else
    # \n is precaution for case where file ends without trailing newline
    printf '\n# Per %s: Set %s in %s\n' "$cce" "$formatted_output" "$config_file" >> "$config_file"
    printf '%s\n' "$formatted_output" >> "$config_file"
  fi
}
replace_or_append $AUDITCONFIG '^admin_space_left_action' "$var_auditd_admin_space_left_action" "CCE-27239-3"

# END fix for 'xccdf_org.ssgproject.content_rule_auditd_data_retention_admin_space_left_action'

###############################################################################
# BEGIN fix (91 / 114) for 'xccdf_org.ssgproject.content_rule_auditd_data_disk_full_action'
###############################################################################
(>&2 echo "Remediating rule 91/114: 'xccdf_org.ssgproject.content_rule_auditd_data_disk_full_action'")

var_auditd_disk_full_action="single"
# Function to replace configuration setting in config file or add the configuration setting if
# it does not exist.
#
# Expects arguments:
#
# config_file:		Configuration file that will be modified
# key:			Configuration option to change
# value:		Value of the configuration option to change
# cce:			The CCE identifier or '@CCENUM@' if no CCE identifier exists
# format:		The printf-like format string that will be given stripped key and value as arguments,
#			so e.g. '%s=%s' will result in key=value subsitution (i.e. without spaces around =)
#
# Optional arugments:
#
# format:		Optional argument to specify the format of how key/value should be
# 			modified/appended in the configuration file. The default is key = value.
#
# Example Call(s):
#
#     With default format of 'key = value':
#     replace_or_append '/etc/sysctl.conf' '^kernel.randomize_va_space' '2' '@CCENUM@'
#
#     With custom key/value format:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' 'disabled' '@CCENUM@' '%s=%s'
#
#     With a variable:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' $var_selinux_state '@CCENUM@' '%s=%s'
#
function replace_or_append {
  local default_format='%s = %s' case_insensitive_mode=yes sed_case_insensitive_option='' grep_case_insensitive_option=''
  local config_file=$1
  local key=$2
  local value=$3
  local cce=$4
  local format=$5

  if [ "$case_insensitive_mode" = yes ]; then
    sed_case_insensitive_option="i"
    grep_case_insensitive_option="-i"
  fi
  [ -n "$format" ] || format="$default_format"
  # Check sanity of the input
  [ $# -ge "3" ] || { echo "Usage: replace_or_append <config_file_location> <key_to_search> <new_value> [<CCE number or literal '@CCENUM@' if unknown>] [printf-like format, default is '$default_format']" >&2; exit 1; }

  # Test if the config_file is a symbolic link. If so, use --follow-symlinks with sed.
  # Otherwise, regular sed command will do.
  sed_command=('sed' '-i')
  if test -L "$config_file"; then
    sed_command+=('--follow-symlinks')
  fi

  # Test that the cce arg is not empty or does not equal @CCENUM@.
  # If @CCENUM@ exists, it means that there is no CCE assigned.
  if [ -n "$cce" ] && [ "$cce" != '@CCENUM@' ]; then
    cce="${cce}"
  else
    cce="CCE"
  fi

  # Strip any search characters in the key arg so that the key can be replaced without
  # adding any search characters to the config file.
  stripped_key=$(sed 's/[\^=\$,;+]*//g' <<< "$key")

  # shellcheck disable=SC2059
  printf -v formatted_output "$format" "$stripped_key" "$value"

  # If the key exists, change it. Otherwise, add it to the config_file.
  # We search for the key string followed by a word boundary (matched by \>),
  # so if we search for 'setting', 'setting2' won't match.
  if LC_ALL=C grep -q -m 1 $grep_case_insensitive_option -e "${key}\\>" "$config_file"; then
    "${sed_command[@]}" "s/${key}\\>.*/$formatted_output/g$sed_case_insensitive_option" "$config_file"
  else
    # \n is precaution for case where file ends without trailing newline
    printf '\n# Per %s: Set %s in %s\n' "$cce" "$formatted_output" "$config_file" >> "$config_file"
    printf '%s\n' "$formatted_output" >> "$config_file"
  fi
}
replace_or_append /etc/audit/auditd.conf '^disk_full_action' "$var_auditd_disk_full_action" "CCE-80500-2"

# END fix for 'xccdf_org.ssgproject.content_rule_auditd_data_disk_full_action'

###############################################################################
# BEGIN fix (92 / 114) for 'xccdf_org.ssgproject.content_rule_mount_option_dev_shm_nosuid'
###############################################################################
(>&2 echo "Remediating rule 92/114: 'xccdf_org.ssgproject.content_rule_mount_option_dev_shm_nosuid'")
function include_mount_options_functions {
	:
}

# $1: type of filesystem
# $2: new mount point option
# $3: filesystem of new mount point (used when adding new entry in fstab)
# $4: mount type of new mount point (used when adding new entry in fstab)
function ensure_mount_option_for_vfstype {
        local _vfstype="$1" _new_opt="$2" _filesystem=$3 _type=$4 _vfstype_points=()
        readarray -t _vfstype_points < <(grep -E "[[:space:]]${_vfstype}[[:space:]]" /etc/fstab | awk '{print $2}')

        for _vfstype_point in "${_vfstype_points[@]}"
        do
                ensure_mount_option_in_fstab "$_vfstype_point" "$_new_opt" "$_filesystem" "$_type"
        done
}

# $1: mount point
# $2: new mount point option
# $3: device or virtual string (used when adding new entry in fstab)
# $4: mount type of mount point (used when adding new entry in fstab)
function ensure_mount_option_in_fstab {
	local _mount_point="$1" _new_opt="$2" _device=$3 _type=$4
	local _mount_point_match_regexp="" _previous_mount_opts=""
	_mount_point_match_regexp="$(get_mount_point_regexp "$_mount_point")"

	if [ "$(grep -c "$_mount_point_match_regexp" /etc/fstab)" -eq 0 ]; then
		# runtime opts without some automatic kernel/userspace-added defaults
		_previous_mount_opts=$(grep "$_mount_point_match_regexp" /etc/mtab | head -1 |  awk '{print $4}' \
					| sed -E "s/(rw|defaults|seclabel|${_new_opt})(,|$)//g;s/,$//")
		[ "$_previous_mount_opts" ] && _previous_mount_opts+=","
		echo "${_device} ${_mount_point} ${_type} defaults,${_previous_mount_opts}${_new_opt} 0 0" >> /etc/fstab
	elif [ "$(grep "$_mount_point_match_regexp" /etc/fstab | grep -c "$_new_opt")" -eq 0 ]; then
		_previous_mount_opts=$(grep "$_mount_point_match_regexp" /etc/fstab | awk '{print $4}')
		sed -i "s|\(${_mount_point_match_regexp}.*${_previous_mount_opts}\)|\1,${_new_opt}|" /etc/fstab
	fi
}

# $1: mount point
function get_mount_point_regexp {
		printf "[[:space:]]%s[[:space:]]" "$1"
}

# $1: mount point
function assert_mount_point_in_fstab {
	local _mount_point_match_regexp
	_mount_point_match_regexp="$(get_mount_point_regexp "$1")"
	grep "$_mount_point_match_regexp" -q /etc/fstab \
		|| { echo "The mount point '$1' is not even in /etc/fstab, so we can't set up mount options" >&2; return 1; }
}

# $1: mount point
function remove_defaults_from_fstab_if_overriden {
	local _mount_point_match_regexp
	_mount_point_match_regexp="$(get_mount_point_regexp "$1")"
	if grep "$_mount_point_match_regexp" /etc/fstab | grep -q "defaults,"
	then
		sed -i "s|\(${_mount_point_match_regexp}.*\)defaults,|\1|" /etc/fstab
	fi
}

# $1: mount point
function ensure_partition_is_mounted {
	local _mount_point="$1"
	mkdir -p "$_mount_point" || return 1
	if mountpoint -q "$_mount_point"; then
		mount -o remount --target "$_mount_point"
	else
		mount --target "$_mount_point"
	fi
}
include_mount_options_functions

function perform_remediation {
	# test "$mount_has_to_exist" = 'yes'
	if test "yes" = 'yes'; then
		assert_mount_point_in_fstab /dev/shm || { echo "Not remediating, because there is no record of /dev/shm in /etc/fstab" >&2; return 1; }
	fi

	ensure_mount_option_in_fstab "/dev/shm" "nosuid" "" ""

	ensure_partition_is_mounted "/dev/shm"
}

perform_remediation

# END fix for 'xccdf_org.ssgproject.content_rule_mount_option_dev_shm_nosuid'

###############################################################################
# BEGIN fix (93 / 114) for 'xccdf_org.ssgproject.content_rule_mount_option_dev_shm_noexec'
###############################################################################
(>&2 echo "Remediating rule 93/114: 'xccdf_org.ssgproject.content_rule_mount_option_dev_shm_noexec'")
function include_mount_options_functions {
	:
}

# $1: type of filesystem
# $2: new mount point option
# $3: filesystem of new mount point (used when adding new entry in fstab)
# $4: mount type of new mount point (used when adding new entry in fstab)
function ensure_mount_option_for_vfstype {
        local _vfstype="$1" _new_opt="$2" _filesystem=$3 _type=$4 _vfstype_points=()
        readarray -t _vfstype_points < <(grep -E "[[:space:]]${_vfstype}[[:space:]]" /etc/fstab | awk '{print $2}')

        for _vfstype_point in "${_vfstype_points[@]}"
        do
                ensure_mount_option_in_fstab "$_vfstype_point" "$_new_opt" "$_filesystem" "$_type"
        done
}

# $1: mount point
# $2: new mount point option
# $3: device or virtual string (used when adding new entry in fstab)
# $4: mount type of mount point (used when adding new entry in fstab)
function ensure_mount_option_in_fstab {
	local _mount_point="$1" _new_opt="$2" _device=$3 _type=$4
	local _mount_point_match_regexp="" _previous_mount_opts=""
	_mount_point_match_regexp="$(get_mount_point_regexp "$_mount_point")"

	if [ "$(grep -c "$_mount_point_match_regexp" /etc/fstab)" -eq 0 ]; then
		# runtime opts without some automatic kernel/userspace-added defaults
		_previous_mount_opts=$(grep "$_mount_point_match_regexp" /etc/mtab | head -1 |  awk '{print $4}' \
					| sed -E "s/(rw|defaults|seclabel|${_new_opt})(,|$)//g;s/,$//")
		[ "$_previous_mount_opts" ] && _previous_mount_opts+=","
		echo "${_device} ${_mount_point} ${_type} defaults,${_previous_mount_opts}${_new_opt} 0 0" >> /etc/fstab
	elif [ "$(grep "$_mount_point_match_regexp" /etc/fstab | grep -c "$_new_opt")" -eq 0 ]; then
		_previous_mount_opts=$(grep "$_mount_point_match_regexp" /etc/fstab | awk '{print $4}')
		sed -i "s|\(${_mount_point_match_regexp}.*${_previous_mount_opts}\)|\1,${_new_opt}|" /etc/fstab
	fi
}

# $1: mount point
function get_mount_point_regexp {
		printf "[[:space:]]%s[[:space:]]" "$1"
}

# $1: mount point
function assert_mount_point_in_fstab {
	local _mount_point_match_regexp
	_mount_point_match_regexp="$(get_mount_point_regexp "$1")"
	grep "$_mount_point_match_regexp" -q /etc/fstab \
		|| { echo "The mount point '$1' is not even in /etc/fstab, so we can't set up mount options" >&2; return 1; }
}

# $1: mount point
function remove_defaults_from_fstab_if_overriden {
	local _mount_point_match_regexp
	_mount_point_match_regexp="$(get_mount_point_regexp "$1")"
	if grep "$_mount_point_match_regexp" /etc/fstab | grep -q "defaults,"
	then
		sed -i "s|\(${_mount_point_match_regexp}.*\)defaults,|\1|" /etc/fstab
	fi
}

# $1: mount point
function ensure_partition_is_mounted {
	local _mount_point="$1"
	mkdir -p "$_mount_point" || return 1
	if mountpoint -q "$_mount_point"; then
		mount -o remount --target "$_mount_point"
	else
		mount --target "$_mount_point"
	fi
}
include_mount_options_functions

function perform_remediation {
	# test "$mount_has_to_exist" = 'yes'
	if test "yes" = 'yes'; then
		assert_mount_point_in_fstab /dev/shm || { echo "Not remediating, because there is no record of /dev/shm in /etc/fstab" >&2; return 1; }
	fi

	ensure_mount_option_in_fstab "/dev/shm" "noexec" "" ""

	ensure_partition_is_mounted "/dev/shm"
}

perform_remediation

# END fix for 'xccdf_org.ssgproject.content_rule_mount_option_dev_shm_noexec'

###############################################################################
# BEGIN fix (94 / 114) for 'xccdf_org.ssgproject.content_rule_mount_option_dev_shm_nodev'
###############################################################################
(>&2 echo "Remediating rule 94/114: 'xccdf_org.ssgproject.content_rule_mount_option_dev_shm_nodev'")
function include_mount_options_functions {
	:
}

# $1: type of filesystem
# $2: new mount point option
# $3: filesystem of new mount point (used when adding new entry in fstab)
# $4: mount type of new mount point (used when adding new entry in fstab)
function ensure_mount_option_for_vfstype {
        local _vfstype="$1" _new_opt="$2" _filesystem=$3 _type=$4 _vfstype_points=()
        readarray -t _vfstype_points < <(grep -E "[[:space:]]${_vfstype}[[:space:]]" /etc/fstab | awk '{print $2}')

        for _vfstype_point in "${_vfstype_points[@]}"
        do
                ensure_mount_option_in_fstab "$_vfstype_point" "$_new_opt" "$_filesystem" "$_type"
        done
}

# $1: mount point
# $2: new mount point option
# $3: device or virtual string (used when adding new entry in fstab)
# $4: mount type of mount point (used when adding new entry in fstab)
function ensure_mount_option_in_fstab {
	local _mount_point="$1" _new_opt="$2" _device=$3 _type=$4
	local _mount_point_match_regexp="" _previous_mount_opts=""
	_mount_point_match_regexp="$(get_mount_point_regexp "$_mount_point")"

	if [ "$(grep -c "$_mount_point_match_regexp" /etc/fstab)" -eq 0 ]; then
		# runtime opts without some automatic kernel/userspace-added defaults
		_previous_mount_opts=$(grep "$_mount_point_match_regexp" /etc/mtab | head -1 |  awk '{print $4}' \
					| sed -E "s/(rw|defaults|seclabel|${_new_opt})(,|$)//g;s/,$//")
		[ "$_previous_mount_opts" ] && _previous_mount_opts+=","
		echo "${_device} ${_mount_point} ${_type} defaults,${_previous_mount_opts}${_new_opt} 0 0" >> /etc/fstab
	elif [ "$(grep "$_mount_point_match_regexp" /etc/fstab | grep -c "$_new_opt")" -eq 0 ]; then
		_previous_mount_opts=$(grep "$_mount_point_match_regexp" /etc/fstab | awk '{print $4}')
		sed -i "s|\(${_mount_point_match_regexp}.*${_previous_mount_opts}\)|\1,${_new_opt}|" /etc/fstab
	fi
}

# $1: mount point
function get_mount_point_regexp {
		printf "[[:space:]]%s[[:space:]]" "$1"
}

# $1: mount point
function assert_mount_point_in_fstab {
	local _mount_point_match_regexp
	_mount_point_match_regexp="$(get_mount_point_regexp "$1")"
	grep "$_mount_point_match_regexp" -q /etc/fstab \
		|| { echo "The mount point '$1' is not even in /etc/fstab, so we can't set up mount options" >&2; return 1; }
}

# $1: mount point
function remove_defaults_from_fstab_if_overriden {
	local _mount_point_match_regexp
	_mount_point_match_regexp="$(get_mount_point_regexp "$1")"
	if grep "$_mount_point_match_regexp" /etc/fstab | grep -q "defaults,"
	then
		sed -i "s|\(${_mount_point_match_regexp}.*\)defaults,|\1|" /etc/fstab
	fi
}

# $1: mount point
function ensure_partition_is_mounted {
	local _mount_point="$1"
	mkdir -p "$_mount_point" || return 1
	if mountpoint -q "$_mount_point"; then
		mount -o remount --target "$_mount_point"
	else
		mount --target "$_mount_point"
	fi
}
include_mount_options_functions

function perform_remediation {
	# test "$mount_has_to_exist" = 'yes'
	if test "yes" = 'yes'; then
		assert_mount_point_in_fstab /dev/shm || { echo "Not remediating, because there is no record of /dev/shm in /etc/fstab" >&2; return 1; }
	fi

	ensure_mount_option_in_fstab "/dev/shm" "nodev" "" ""

	ensure_partition_is_mounted "/dev/shm"
}

perform_remediation

# END fix for 'xccdf_org.ssgproject.content_rule_mount_option_dev_shm_nodev'

###############################################################################
# BEGIN fix (95 / 114) for 'xccdf_org.ssgproject.content_rule_mount_option_tmp_noexec'
###############################################################################
(>&2 echo "Remediating rule 95/114: 'xccdf_org.ssgproject.content_rule_mount_option_tmp_noexec'")
function include_mount_options_functions {
	:
}

# $1: type of filesystem
# $2: new mount point option
# $3: filesystem of new mount point (used when adding new entry in fstab)
# $4: mount type of new mount point (used when adding new entry in fstab)
function ensure_mount_option_for_vfstype {
        local _vfstype="$1" _new_opt="$2" _filesystem=$3 _type=$4 _vfstype_points=()
        readarray -t _vfstype_points < <(grep -E "[[:space:]]${_vfstype}[[:space:]]" /etc/fstab | awk '{print $2}')

        for _vfstype_point in "${_vfstype_points[@]}"
        do
                ensure_mount_option_in_fstab "$_vfstype_point" "$_new_opt" "$_filesystem" "$_type"
        done
}

# $1: mount point
# $2: new mount point option
# $3: device or virtual string (used when adding new entry in fstab)
# $4: mount type of mount point (used when adding new entry in fstab)
function ensure_mount_option_in_fstab {
	local _mount_point="$1" _new_opt="$2" _device=$3 _type=$4
	local _mount_point_match_regexp="" _previous_mount_opts=""
	_mount_point_match_regexp="$(get_mount_point_regexp "$_mount_point")"

	if [ "$(grep -c "$_mount_point_match_regexp" /etc/fstab)" -eq 0 ]; then
		# runtime opts without some automatic kernel/userspace-added defaults
		_previous_mount_opts=$(grep "$_mount_point_match_regexp" /etc/mtab | head -1 |  awk '{print $4}' \
					| sed -E "s/(rw|defaults|seclabel|${_new_opt})(,|$)//g;s/,$//")
		[ "$_previous_mount_opts" ] && _previous_mount_opts+=","
		echo "${_device} ${_mount_point} ${_type} defaults,${_previous_mount_opts}${_new_opt} 0 0" >> /etc/fstab
	elif [ "$(grep "$_mount_point_match_regexp" /etc/fstab | grep -c "$_new_opt")" -eq 0 ]; then
		_previous_mount_opts=$(grep "$_mount_point_match_regexp" /etc/fstab | awk '{print $4}')
		sed -i "s|\(${_mount_point_match_regexp}.*${_previous_mount_opts}\)|\1,${_new_opt}|" /etc/fstab
	fi
}

# $1: mount point
function get_mount_point_regexp {
		printf "[[:space:]]%s[[:space:]]" "$1"
}

# $1: mount point
function assert_mount_point_in_fstab {
	local _mount_point_match_regexp
	_mount_point_match_regexp="$(get_mount_point_regexp "$1")"
	grep "$_mount_point_match_regexp" -q /etc/fstab \
		|| { echo "The mount point '$1' is not even in /etc/fstab, so we can't set up mount options" >&2; return 1; }
}

# $1: mount point
function remove_defaults_from_fstab_if_overriden {
	local _mount_point_match_regexp
	_mount_point_match_regexp="$(get_mount_point_regexp "$1")"
	if grep "$_mount_point_match_regexp" /etc/fstab | grep -q "defaults,"
	then
		sed -i "s|\(${_mount_point_match_regexp}.*\)defaults,|\1|" /etc/fstab
	fi
}

# $1: mount point
function ensure_partition_is_mounted {
	local _mount_point="$1"
	mkdir -p "$_mount_point" || return 1
	if mountpoint -q "$_mount_point"; then
		mount -o remount --target "$_mount_point"
	else
		mount --target "$_mount_point"
	fi
}
include_mount_options_functions

function perform_remediation {
	# test "$mount_has_to_exist" = 'yes'
	if test "yes" = 'yes'; then
		assert_mount_point_in_fstab /tmp || { echo "Not remediating, because there is no record of /tmp in /etc/fstab" >&2; return 1; }
	fi

	ensure_mount_option_in_fstab "/tmp" "noexec" "" ""

	ensure_partition_is_mounted "/tmp"
}

perform_remediation

# END fix for 'xccdf_org.ssgproject.content_rule_mount_option_tmp_noexec'

###############################################################################
# BEGIN fix (96 / 114) for 'xccdf_org.ssgproject.content_rule_service_autofs_disabled'
###############################################################################
(>&2 echo "Remediating rule 96/114: 'xccdf_org.ssgproject.content_rule_service_autofs_disabled'")

/sbin/service 'autofs' stop
/sbin/chkconfig --level 0123456 'autofs' off

# END fix for 'xccdf_org.ssgproject.content_rule_service_autofs_disabled'

###############################################################################
# BEGIN fix (97 / 114) for 'xccdf_org.ssgproject.content_rule_kernel_module_usb-storage_disabled'
###############################################################################
(>&2 echo "Remediating rule 97/114: 'xccdf_org.ssgproject.content_rule_kernel_module_usb-storage_disabled'")
if LC_ALL=C grep -q -m 1 "^install usb-storage" /etc/modprobe.d/usb-storage.conf ; then
	sed -i 's/^install usb-storage.*/install usb-storage /bin/true/g' /etc/modprobe.d/usb-storage.conf
else
	echo -e "\n# Disable per security requirements" >> /etc/modprobe.d/usb-storage.conf
	echo "install usb-storage /bin/true" >> /etc/modprobe.d/usb-storage.conf
fi

# END fix for 'xccdf_org.ssgproject.content_rule_kernel_module_usb-storage_disabled'

###############################################################################
# BEGIN fix (98 / 114) for 'xccdf_org.ssgproject.content_rule_disable_users_coredumps'
###############################################################################
(>&2 echo "Remediating rule 98/114: 'xccdf_org.ssgproject.content_rule_disable_users_coredumps'")
SECURITY_LIMITS_FILE="/etc/security/limits.conf"

if grep -qE '\*\s+hard\s+core' $SECURITY_LIMITS_FILE; then
        sed -ri 's/(hard\s+core\s+)[[:digit:]]+/\1 0/' $SECURITY_LIMITS_FILE
else
        echo "*     hard   core    0" >> $SECURITY_LIMITS_FILE
fi

# END fix for 'xccdf_org.ssgproject.content_rule_disable_users_coredumps'

###############################################################################
# BEGIN fix (99 / 114) for 'xccdf_org.ssgproject.content_rule_umask_for_daemons'
###############################################################################
(>&2 echo "Remediating rule 99/114: 'xccdf_org.ssgproject.content_rule_umask_for_daemons'")

var_umask_for_daemons="027"

grep -q ^umask /etc/init.d/functions && \
  sed -i "s/umask.*/umask $var_umask_for_daemons/g" /etc/init.d/functions
if ! [ $? -eq 0 ]; then
    echo "umask $var_umask_for_daemons" >> /etc/init.d/functions
fi

# END fix for 'xccdf_org.ssgproject.content_rule_umask_for_daemons'

###############################################################################
# BEGIN fix (100 / 114) for 'xccdf_org.ssgproject.content_rule_sysctl_kernel_randomize_va_space'
###############################################################################
(>&2 echo "Remediating rule 100/114: 'xccdf_org.ssgproject.content_rule_sysctl_kernel_randomize_va_space'")


#
# Set runtime for kernel.randomize_va_space
#
/sbin/sysctl -q -n -w kernel.randomize_va_space="2"

#
# If kernel.randomize_va_space present in /etc/sysctl.conf, change value to "2"
#	else, add "kernel.randomize_va_space = 2" to /etc/sysctl.conf
#
# Function to replace configuration setting in config file or add the configuration setting if
# it does not exist.
#
# Expects arguments:
#
# config_file:		Configuration file that will be modified
# key:			Configuration option to change
# value:		Value of the configuration option to change
# cce:			The CCE identifier or '@CCENUM@' if no CCE identifier exists
# format:		The printf-like format string that will be given stripped key and value as arguments,
#			so e.g. '%s=%s' will result in key=value subsitution (i.e. without spaces around =)
#
# Optional arugments:
#
# format:		Optional argument to specify the format of how key/value should be
# 			modified/appended in the configuration file. The default is key = value.
#
# Example Call(s):
#
#     With default format of 'key = value':
#     replace_or_append '/etc/sysctl.conf' '^kernel.randomize_va_space' '2' '@CCENUM@'
#
#     With custom key/value format:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' 'disabled' '@CCENUM@' '%s=%s'
#
#     With a variable:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' $var_selinux_state '@CCENUM@' '%s=%s'
#
function replace_or_append {
  local default_format='%s = %s' case_insensitive_mode=yes sed_case_insensitive_option='' grep_case_insensitive_option=''
  local config_file=$1
  local key=$2
  local value=$3
  local cce=$4
  local format=$5

  if [ "$case_insensitive_mode" = yes ]; then
    sed_case_insensitive_option="i"
    grep_case_insensitive_option="-i"
  fi
  [ -n "$format" ] || format="$default_format"
  # Check sanity of the input
  [ $# -ge "3" ] || { echo "Usage: replace_or_append <config_file_location> <key_to_search> <new_value> [<CCE number or literal '@CCENUM@' if unknown>] [printf-like format, default is '$default_format']" >&2; exit 1; }

  # Test if the config_file is a symbolic link. If so, use --follow-symlinks with sed.
  # Otherwise, regular sed command will do.
  sed_command=('sed' '-i')
  if test -L "$config_file"; then
    sed_command+=('--follow-symlinks')
  fi

  # Test that the cce arg is not empty or does not equal @CCENUM@.
  # If @CCENUM@ exists, it means that there is no CCE assigned.
  if [ -n "$cce" ] && [ "$cce" != '@CCENUM@' ]; then
    cce="${cce}"
  else
    cce="CCE"
  fi

  # Strip any search characters in the key arg so that the key can be replaced without
  # adding any search characters to the config file.
  stripped_key=$(sed 's/[\^=\$,;+]*//g' <<< "$key")

  # shellcheck disable=SC2059
  printf -v formatted_output "$format" "$stripped_key" "$value"

  # If the key exists, change it. Otherwise, add it to the config_file.
  # We search for the key string followed by a word boundary (matched by \>),
  # so if we search for 'setting', 'setting2' won't match.
  if LC_ALL=C grep -q -m 1 $grep_case_insensitive_option -e "${key}\\>" "$config_file"; then
    "${sed_command[@]}" "s/${key}\\>.*/$formatted_output/g$sed_case_insensitive_option" "$config_file"
  else
    # \n is precaution for case where file ends without trailing newline
    printf '\n# Per %s: Set %s in %s\n' "$cce" "$formatted_output" "$config_file" >> "$config_file"
    printf '%s\n' "$formatted_output" >> "$config_file"
  fi
}
replace_or_append '/etc/sysctl.conf' '^kernel.randomize_va_space' "2" 'CCE-26999-3'

# END fix for 'xccdf_org.ssgproject.content_rule_sysctl_kernel_randomize_va_space'

###############################################################################
# BEGIN fix (101 / 114) for 'xccdf_org.ssgproject.content_rule_file_ownership_binary_dirs'
###############################################################################
(>&2 echo "Remediating rule 101/114: 'xccdf_org.ssgproject.content_rule_file_ownership_binary_dirs'")
find /bin/ \
/usr/bin/ \
/usr/local/bin/ \
/sbin/ \
/usr/sbin/ \
/usr/local/sbin/ \
/usr/libexec \
\! -user root -execdir chown root {} \;

# END fix for 'xccdf_org.ssgproject.content_rule_file_ownership_binary_dirs'

###############################################################################
# BEGIN fix (102 / 114) for 'xccdf_org.ssgproject.content_rule_service_atd_disabled'
###############################################################################
(>&2 echo "Remediating rule 102/114: 'xccdf_org.ssgproject.content_rule_service_atd_disabled'")

/sbin/service 'atd' stop
/sbin/chkconfig --level 0123456 'atd' off

# END fix for 'xccdf_org.ssgproject.content_rule_service_atd_disabled'

###############################################################################
# BEGIN fix (103 / 114) for 'xccdf_org.ssgproject.content_rule_service_abrtd_disabled'
###############################################################################
(>&2 echo "Remediating rule 103/114: 'xccdf_org.ssgproject.content_rule_service_abrtd_disabled'")

/sbin/service 'abrtd' stop
/sbin/chkconfig --level 0123456 'abrtd' off

# END fix for 'xccdf_org.ssgproject.content_rule_service_abrtd_disabled'

###############################################################################
# BEGIN fix (104 / 114) for 'xccdf_org.ssgproject.content_rule_service_rhnsd_disabled'
###############################################################################
(>&2 echo "Remediating rule 104/114: 'xccdf_org.ssgproject.content_rule_service_rhnsd_disabled'")

/sbin/service 'rhnsd' stop
/sbin/chkconfig --level 0123456 'rhnsd' off

# END fix for 'xccdf_org.ssgproject.content_rule_service_rhnsd_disabled'

###############################################################################
# BEGIN fix (105 / 114) for 'xccdf_org.ssgproject.content_rule_package_xorg-x11-server-common_removed'
###############################################################################
(>&2 echo "Remediating rule 105/114: 'xccdf_org.ssgproject.content_rule_package_xorg-x11-server-common_removed'")

# CAUTION: This remediation script will remove xorg-x11-server-common
#	   from the system, and may remove any packages
#	   that depend on xorg-x11-server-common. Execute this
#	   remediation AFTER testing on a non-production
#	   system!

#if rpm -q --quiet "xorg-x11-server-common" ; then
#    yum remove -y "xorg-x11-server-common"
#fi

# END fix for 'xccdf_org.ssgproject.content_rule_package_xorg-x11-server-common_removed'

###############################################################################
# BEGIN fix (106 / 114) for 'xccdf_org.ssgproject.content_rule_xwindows_runlevel_setting'
###############################################################################
(>&2 echo "Remediating rule 106/114: 'xccdf_org.ssgproject.content_rule_xwindows_runlevel_setting'")
(>&2 echo "FIX FOR THIS RULE 'xccdf_org.ssgproject.content_rule_xwindows_runlevel_setting' IS MISSING!")

# END fix for 'xccdf_org.ssgproject.content_rule_xwindows_runlevel_setting'

###############################################################################
# BEGIN fix (107 / 114) for 'xccdf_org.ssgproject.content_rule_require_smb_client_signing'
###############################################################################
(>&2 echo "Remediating rule 107/114: 'xccdf_org.ssgproject.content_rule_require_smb_client_signing'")
######################################################################
#By Luke "Brisk-OH" Brisk
#luke.brisk@boeing.com or luke.brisk@gmail.com
######################################################################

CLIENTSIGNING=$( grep -ic 'client signing' /etc/samba/smb.conf )

if [ "$CLIENTSIGNING" -eq 0 ];  then
	# Add to global section
	sed -i 's/\[global\]/\[global\]\n\n\tclient signing = mandatory/g' /etc/samba/smb.conf
else
	sed -i 's/[[:blank:]]*client[[:blank:]]signing[[:blank:]]*=[[:blank:]]*no/        client signing = mandatory/g' /etc/samba/smb.conf
fi

# END fix for 'xccdf_org.ssgproject.content_rule_require_smb_client_signing'

###############################################################################
# BEGIN fix (108 / 114) for 'xccdf_org.ssgproject.content_rule_sysconfig_networking_bootproto_ifcfg'
###############################################################################
(>&2 echo "Remediating rule 108/114: 'xccdf_org.ssgproject.content_rule_sysconfig_networking_bootproto_ifcfg'")
(>&2 echo "FIX FOR THIS RULE 'xccdf_org.ssgproject.content_rule_sysconfig_networking_bootproto_ifcfg' IS MISSING!")

# END fix for 'xccdf_org.ssgproject.content_rule_sysconfig_networking_bootproto_ifcfg'

###############################################################################
# BEGIN fix (109 / 114) for 'xccdf_org.ssgproject.content_rule_sshd_set_idle_timeout'
###############################################################################
(>&2 echo "Remediating rule 109/114: 'xccdf_org.ssgproject.content_rule_sshd_set_idle_timeout'")

sshd_idle_timeout_value="900"
# Function to replace configuration setting in config file or add the configuration setting if
# it does not exist.
#
# Expects arguments:
#
# config_file:		Configuration file that will be modified
# key:			Configuration option to change
# value:		Value of the configuration option to change
# cce:			The CCE identifier or '@CCENUM@' if no CCE identifier exists
# format:		The printf-like format string that will be given stripped key and value as arguments,
#			so e.g. '%s=%s' will result in key=value subsitution (i.e. without spaces around =)
#
# Optional arugments:
#
# format:		Optional argument to specify the format of how key/value should be
# 			modified/appended in the configuration file. The default is key = value.
#
# Example Call(s):
#
#     With default format of 'key = value':
#     replace_or_append '/etc/sysctl.conf' '^kernel.randomize_va_space' '2' '@CCENUM@'
#
#     With custom key/value format:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' 'disabled' '@CCENUM@' '%s=%s'
#
#     With a variable:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' $var_selinux_state '@CCENUM@' '%s=%s'
#
function replace_or_append {
  local default_format='%s = %s' case_insensitive_mode=yes sed_case_insensitive_option='' grep_case_insensitive_option=''
  local config_file=$1
  local key=$2
  local value=$3
  local cce=$4
  local format=$5

  if [ "$case_insensitive_mode" = yes ]; then
    sed_case_insensitive_option="i"
    grep_case_insensitive_option="-i"
  fi
  [ -n "$format" ] || format="$default_format"
  # Check sanity of the input
  [ $# -ge "3" ] || { echo "Usage: replace_or_append <config_file_location> <key_to_search> <new_value> [<CCE number or literal '@CCENUM@' if unknown>] [printf-like format, default is '$default_format']" >&2; exit 1; }

  # Test if the config_file is a symbolic link. If so, use --follow-symlinks with sed.
  # Otherwise, regular sed command will do.
  sed_command=('sed' '-i')
  if test -L "$config_file"; then
    sed_command+=('--follow-symlinks')
  fi

  # Test that the cce arg is not empty or does not equal @CCENUM@.
  # If @CCENUM@ exists, it means that there is no CCE assigned.
  if [ -n "$cce" ] && [ "$cce" != '@CCENUM@' ]; then
    cce="${cce}"
  else
    cce="CCE"
  fi

  # Strip any search characters in the key arg so that the key can be replaced without
  # adding any search characters to the config file.
  stripped_key=$(sed 's/[\^=\$,;+]*//g' <<< "$key")

  # shellcheck disable=SC2059
  printf -v formatted_output "$format" "$stripped_key" "$value"

  # If the key exists, change it. Otherwise, add it to the config_file.
  # We search for the key string followed by a word boundary (matched by \>),
  # so if we search for 'setting', 'setting2' won't match.
  if LC_ALL=C grep -q -m 1 $grep_case_insensitive_option -e "${key}\\>" "$config_file"; then
    "${sed_command[@]}" "s/${key}\\>.*/$formatted_output/g$sed_case_insensitive_option" "$config_file"
  else
    # \n is precaution for case where file ends without trailing newline
    printf '\n# Per %s: Set %s in %s\n' "$cce" "$formatted_output" "$config_file" >> "$config_file"
    printf '%s\n' "$formatted_output" >> "$config_file"
  fi
}
replace_or_append '/etc/ssh/sshd_config' '^ClientAliveInterval' $sshd_idle_timeout_value 'CCE-26919-1' '%s %s'

# END fix for 'xccdf_org.ssgproject.content_rule_sshd_set_idle_timeout'

###############################################################################
# BEGIN fix (110 / 114) for 'xccdf_org.ssgproject.content_rule_sshd_set_keepalive'
###############################################################################
(>&2 echo "Remediating rule 110/114: 'xccdf_org.ssgproject.content_rule_sshd_set_keepalive'")

var_sshd_set_keepalive="0"
# Function to replace configuration setting in config file or add the configuration setting if
# it does not exist.
#
# Expects arguments:
#
# config_file:		Configuration file that will be modified
# key:			Configuration option to change
# value:		Value of the configuration option to change
# cce:			The CCE identifier or '@CCENUM@' if no CCE identifier exists
# format:		The printf-like format string that will be given stripped key and value as arguments,
#			so e.g. '%s=%s' will result in key=value subsitution (i.e. without spaces around =)
#
# Optional arugments:
#
# format:		Optional argument to specify the format of how key/value should be
# 			modified/appended in the configuration file. The default is key = value.
#
# Example Call(s):
#
#     With default format of 'key = value':
#     replace_or_append '/etc/sysctl.conf' '^kernel.randomize_va_space' '2' '@CCENUM@'
#
#     With custom key/value format:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' 'disabled' '@CCENUM@' '%s=%s'
#
#     With a variable:
#     replace_or_append '/etc/sysconfig/selinux' '^SELINUX=' $var_selinux_state '@CCENUM@' '%s=%s'
#
function replace_or_append {
  local default_format='%s = %s' case_insensitive_mode=yes sed_case_insensitive_option='' grep_case_insensitive_option=''
  local config_file=$1
  local key=$2
  local value=$3
  local cce=$4
  local format=$5

  if [ "$case_insensitive_mode" = yes ]; then
    sed_case_insensitive_option="i"
    grep_case_insensitive_option="-i"
  fi
  [ -n "$format" ] || format="$default_format"
  # Check sanity of the input
  [ $# -ge "3" ] || { echo "Usage: replace_or_append <config_file_location> <key_to_search> <new_value> [<CCE number or literal '@CCENUM@' if unknown>] [printf-like format, default is '$default_format']" >&2; exit 1; }

  # Test if the config_file is a symbolic link. If so, use --follow-symlinks with sed.
  # Otherwise, regular sed command will do.
  sed_command=('sed' '-i')
  if test -L "$config_file"; then
    sed_command+=('--follow-symlinks')
  fi

  # Test that the cce arg is not empty or does not equal @CCENUM@.
  # If @CCENUM@ exists, it means that there is no CCE assigned.
  if [ -n "$cce" ] && [ "$cce" != '@CCENUM@' ]; then
    cce="${cce}"
  else
    cce="CCE"
  fi

  # Strip any search characters in the key arg so that the key can be replaced without
  # adding any search characters to the config file.
  stripped_key=$(sed 's/[\^=\$,;+]*//g' <<< "$key")

  # shellcheck disable=SC2059
  printf -v formatted_output "$format" "$stripped_key" "$value"

  # If the key exists, change it. Otherwise, add it to the config_file.
  # We search for the key string followed by a word boundary (matched by \>),
  # so if we search for 'setting', 'setting2' won't match.
  if LC_ALL=C grep -q -m 1 $grep_case_insensitive_option -e "${key}\\>" "$config_file"; then
    "${sed_command[@]}" "s/${key}\\>.*/$formatted_output/g$sed_case_insensitive_option" "$config_file"
  else
    # \n is precaution for case where file ends without trailing newline
    printf '\n# Per %s: Set %s in %s\n' "$cce" "$formatted_output" "$config_file" >> "$config_file"
    printf '%s\n' "$formatted_output" >> "$config_file"
  fi
}
replace_or_append '/etc/ssh/sshd_config' '^ClientAliveCountMax' "$var_sshd_set_keepalive" 'CCE-26282-4' '%s %s'

# END fix for 'xccdf_org.ssgproject.content_rule_sshd_set_keepalive'

###############################################################################
# BEGIN fix (111 / 114) for 'xccdf_org.ssgproject.content_rule_sshd_enable_warning_banner'
###############################################################################
(>&2 echo "Remediating rule 111/114: 'xccdf_org.ssgproject.content_rule_sshd_enable_warning_banner'")
if [ -e "/etc/ssh/sshd_config" ] ; then
    LC_ALL=C sed -i "/^\s*Banner\s\+/Id" "/etc/ssh/sshd_config"
else
    touch "/etc/ssh/sshd_config"
fi
cp "/etc/ssh/sshd_config" "/etc/ssh/sshd_config.bak"
# Insert before the line matching the regex '^Match'.
line_number="$(LC_ALL=C grep -n "^Match" "/etc/ssh/sshd_config.bak" | LC_ALL=C sed 's/:.*//g')"
if [ -z "$line_number" ]; then
    # There was no match of '^Match', insert at
    # the end of the file.
    printf '%s\n' "Banner /etc/issue" >> "/etc/ssh/sshd_config"
else
    head -n "$(( line_number - 1 ))" "/etc/ssh/sshd_config.bak" > "/etc/ssh/sshd_config"
    printf '%s\n' "Banner /etc/issue" >> "/etc/ssh/sshd_config"
    tail -n "+$(( line_number ))" "/etc/ssh/sshd_config.bak" >> "/etc/ssh/sshd_config"
fi
# Clean up after ourselves.
rm "/etc/ssh/sshd_config.bak"

# END fix for 'xccdf_org.ssgproject.content_rule_sshd_enable_warning_banner'

###############################################################################
# BEGIN fix (112 / 114) for 'xccdf_org.ssgproject.content_rule_sshd_disable_root_login'
###############################################################################
(>&2 echo "Remediating rule 112/114: 'xccdf_org.ssgproject.content_rule_sshd_disable_root_login'")
if [ -e "/etc/ssh/sshd_config" ] ; then
    LC_ALL=C sed -i "/^\s*PermitRootLogin\s\+/Id" "/etc/ssh/sshd_config"
else
    touch "/etc/ssh/sshd_config"
fi
cp "/etc/ssh/sshd_config" "/etc/ssh/sshd_config.bak"
# Insert before the line matching the regex '^Match'.
line_number="$(LC_ALL=C grep -n "^Match" "/etc/ssh/sshd_config.bak" | LC_ALL=C sed 's/:.*//g')"
if [ -z "$line_number" ]; then
    # There was no match of '^Match', insert at
    # the end of the file.
    printf '%s\n' "PermitRootLogin no" >> "/etc/ssh/sshd_config"
else
    head -n "$(( line_number - 1 ))" "/etc/ssh/sshd_config.bak" > "/etc/ssh/sshd_config"
    printf '%s\n' "PermitRootLogin no" >> "/etc/ssh/sshd_config"
    tail -n "+$(( line_number ))" "/etc/ssh/sshd_config.bak" >> "/etc/ssh/sshd_config"
fi
# Clean up after ourselves.
rm "/etc/ssh/sshd_config.bak"

# END fix for 'xccdf_org.ssgproject.content_rule_sshd_disable_root_login'

###############################################################################
# BEGIN fix (113 / 114) for 'xccdf_org.ssgproject.content_rule_sshd_use_approved_ciphers'
###############################################################################
(>&2 echo "Remediating rule 113/114: 'xccdf_org.ssgproject.content_rule_sshd_use_approved_ciphers'")
grep -q ^Ciphers /etc/ssh/sshd_config && \
  sed -i "s/Ciphers.*/Ciphers aes128-ctr,aes192-ctr,aes256-ctr,aes128-cbc,3des-cbc,aes192-cbc,aes256-cbc/g" /etc/ssh/sshd_config
if ! [ $? -eq 0 ]; then
    echo "Ciphers aes128-ctr,aes192-ctr,aes256-ctr,aes128-cbc,3des-cbc,aes192-cbc,aes256-cbc" >> /etc/ssh/sshd_config
fi

# END fix for 'xccdf_org.ssgproject.content_rule_sshd_use_approved_ciphers'

###############################################################################
# BEGIN fix (114 / 114) for 'xccdf_org.ssgproject.content_rule_sshd_do_not_permit_user_env'
###############################################################################
(>&2 echo "Remediating rule 114/114: 'xccdf_org.ssgproject.content_rule_sshd_do_not_permit_user_env'")
if [ -e "/etc/ssh/sshd_config" ] ; then
    LC_ALL=C sed -i "/^\s*PermitUserEnvironment\s\+/Id" "/etc/ssh/sshd_config"
else
    touch "/etc/ssh/sshd_config"
fi
cp "/etc/ssh/sshd_config" "/etc/ssh/sshd_config.bak"
# Insert before the line matching the regex '^Match'.
line_number="$(LC_ALL=C grep -n "^Match" "/etc/ssh/sshd_config.bak" | LC_ALL=C sed 's/:.*//g')"
if [ -z "$line_number" ]; then
    # There was no match of '^Match', insert at
    # the end of the file.
    printf '%s\n' "PermitUserEnvironment no" >> "/etc/ssh/sshd_config"
else
    head -n "$(( line_number - 1 ))" "/etc/ssh/sshd_config.bak" > "/etc/ssh/sshd_config"
    printf '%s\n' "PermitUserEnvironment no" >> "/etc/ssh/sshd_config"
    tail -n "+$(( line_number ))" "/etc/ssh/sshd_config.bak" >> "/etc/ssh/sshd_config"
fi
# Clean up after ourselves.
rm "/etc/ssh/sshd_config.bak"

# END fix for 'xccdf_org.ssgproject.content_rule_sshd_do_not_permit_user_env'

#### Delta from the U_RHEL_6_V1R28_STIG Summer 2020
#### Please add updates and on Github
####
####
####
gconftool-2 \
--direct \
--config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
--type int \
--set /apps/gnome-screensaver/idle_delay 15

##### B3.25 Audit System Alerts
##### GEN002719 - The audit system must alert the SA in the event of an audit processing failure.
##### GEN002730 - The audit system must alert the SA when the audit storage volume approaches its capacity.

unset tester
tester=$(sed -n 's/disk_full_action = syslog/&/p' /etc/audit/auditd.conf);
  if [ -z "$tester" ] 
    then
      sed -i "s/disk_full_action = SUSPEND/disk_full_action = syslog/g" /etc/audit/auditd.conf
    fi
    
unset tester
tester=$(sed -n 's/disk_error_action = SYSLOG/&/p' /etc/audit/auditd.conf);
  if [ -z "$tester" ] 
    then
      sed -i "s/disk_error_action = SUSPEND/disk_error_action = syslog/g" /etc/audit/auditd.conf
    fi

service auditd stop

sleep 1

## Backs up audit.rules file to prestig.audit.rules and checks
## to make sure the original does not get overwritten

if [ ! -e /etc/pam.d/prestig.audit.rules ]
	then
		/bin/cp -f /etc/audit/audit.rules /etc/audit/prestig.audit.rules
	fi

sed -i 's/\-b\ 256/\-b\ 8192/g' /etc/audit/audit.rules

unset tester
tester=$(sed -n 's/^#-e 2/&/p' /etc/audit/audit.rules);

if [ -z "$tester" ] 
  	then
		sed -i "s/^-e 2$/#&/g" /etc/audit/audit.rules
	fi

sed -i '/^-e 1$/q' /etc/audit/audit.rules

### Edited to remove 64 bit rules as in the MUDG

echo >>/etc/audit/audit.rules
echo "#GEN002720 (creat)" >>/etc/audit/audit.rules 
echo "-a exit,always -F arch=b32 -S creat -F exit=-EACCES -F auid!=4294967295 -k open_syscall" >>/etc/audit/audit.rules 
echo "-a exit,always -F arch=b32 -S creat -F exit=-EPERM -F auid!=4294967295 -k open_syscall" >>/etc/audit/audit.rules
echo "-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=500 -F auid!=4294967295 -k access " >>/etc/audit/audit.rules
echo "-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=500 -F auid!=4294967295 -k access" >>/etc/audit/audit.rules
echo "-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid=0 -k access" >>/etc/audit/audit.rules
echo "-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid=0 -k access" >>/etc/audit/audit.rules
echo "-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=500 -F auid!=4294967295 -k access" >>/etc/audit/audit.rules
echo "-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=500 -F auid!=4294967295 -k access" >>/etc/audit/audit.rules
echo "-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid=0 -k access" >>/etc/audit/audit.rules
echo "-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid=0 -k access" >>/etc/audit/audit.rules
#
echo "#RHEL-06-000184 (creat)" >>/etc/audit/audit.rules
echo "-a always,exit -F arch=b32 -S chmod -F auid>=500 -F auid!=4294967295 -k perm_mod" >>/etc/audit/audit.rules
echo "-a always,exit -F arch=b32 -S chmod -F auid=0 -k perm_mod" >>/etc/audit/audit.rules
echo "-a always,exit -F arch=b64 -S chmod -F auid>=500 -F auid!=4294967295 -k perm_mod" >>/etc/audit/audit.rules
echo "-a always,exit -F arch=b64 -S chmod -F auid=0 -k perm_mod" >>/etc/audit/audit.rules
#
echo "#RHEL-06-000185 (creat)" >>/etc/audit/audit.rules
echo "-a always,exit -F arch=b32 -S chown -F auid>=500 -F auid!=4294967295 -k perm_mod" >>/etc/audit/audit.rules
echo "-a always,exit -F arch=b32 -S chown -F auid=0 -k perm_mod" >>/etc/audit/audit.rules
echo "-a always,exit -F arch=b64 -S chown -F auid>=500 -F auid!=4294967295 -k perm_mod" >>/etc/audit/audit.rules
echo "-a always,exit -F arch=b64 -S chown -F auid=0 -k perm_mod" >>/etc/audit/audit.rules
#
echo "#RHEL-06-000186 (creat)" >>/etc/audit/audit.rules
echo "-a always,exit -F arch=b32 -S fchmod -F auid>=500 -F auid!=4294967295 -k perm_mod" >>/etc/audit/audit.rules
echo "-a always,exit -F arch=b32 -S fchmod -F auid=0 -k perm_mod" >>/etc/audit/audit.rules
echo "-a always,exit -F arch=b64 -S fchmod -F auid>=500 -F auid!=4294967295 -k perm_mod" >>/etc/audit/audit.rules
echo "-a always,exit -F arch=b64 -S fchmod -F auid=0 -k perm_mod" >>/etc/audit/audit.rules
#
echo "#RHEL-06-000187 (creat)" >>/etc/audit/audit.rules






clear
echo "#######################################################################################" 
echo "#                                 System Harding Is Complete                          #"
echo "#######################################################################################"
echo ""
echo -e "\033[5;31;47mSystem will reboot in 60 seconds\033[0m"
echo -e "\033[5;31;47mYou have 60 seconds remaining to hit Ctrl+C to cancel this operation!\033[0m"
#Countdown Timer 
function countdown
{
        local OLD_IFS="${IFS}"
        IFS=":"
        local ARR=( $1 )
        local SECONDS=$((  (ARR[0] * 60 * 60) + (ARR[1] * 60) + ARR[2]  ))
        local START=$(date +%s)
        local END=$((START + SECONDS))
        local CUR=$START

        while [[ $CUR -lt $END ]]
        do
                CUR=$(date +%s)
                LEFT=$((END-CUR))

                printf "\r%02d:%02d:%02d" \
                        $((LEFT/3600)) $(( (LEFT/60)%60)) $((LEFT%60))

                sleep 1
        done
        IFS="${OLD_IFS}"
        echo "        "
}

countdown "00:01:00"
#End of Countdown Timer
clear
echo -e "\033[5;31;47mSytem is rebooting please reconnet\033[0m"
shutdown -r now