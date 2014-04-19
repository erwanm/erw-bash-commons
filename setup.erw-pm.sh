#
# EM April 14 (update)
#
# Remark: special case because this is the project which contains the erw-pm system.
# ERW_BASH_COMMONS_PATH should have already been initialized.
#
#echo "debug: in bash-commons setup" 1>&2
if [ -z "$ERW_BASH_COMMONS_PATH" ]; then # normally never!
    echo "Warning: ERW_BASH_COMMONS_PATH is not initialized, calling init-erw-pm.sh"
    source ./init-erw-pm.sh . # assuming we are in the right directory and the call was sourced (?)
fi
addToEnvVar "$ERW_BASH_COMMONS_PATH" PATH ":"
