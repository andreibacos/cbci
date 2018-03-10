#!/bin/bash

TEMPEST_FOLDER=/opt/stack/tempest
TEMPEST_LOGS_FOLDER=/home/ubuntu/tempest

filter_comments() {
    awk 'NF && $1!~/^#/' $1
}

array_to_regex() {
    local ar=(${@})
    local regex=""

    for s in "${ar[@]}"
    do
        if [ "$regex" ]; then
            regex+="|"
        fi
        regex+="^"$(echo $s | sed -e 's/[]\/$*.^|[]/\\&/g')
    done
    echo $regex
}


usage() { echo "Usage: $0 --included-tests included-tests.txt --excluded-tests excluded-tests.txt --isolated-tests isolated-tests.txt" 1>&2; exit 1; }

# read the options
TEMP=$(getopt -o i:e:s: --long included-tests:,excluded-tests:,isolated-tests: -n 'run-tests.sh' -- "$@")
eval set -- "$TEMP"

# extract options and their arguments into variables.
while true ; do
    case "$1" in
        --included-tests) included_tests_file=$2 ; shift 2 ;;
        --excluded-tests) excluded_tests_file=$2 ; shift 2 ;;
        --isolated-tests) isolated_tests_file=$2 ; shift 2 ;;
        --) shift ; break ;;
        *) echo "Invalid options $1"; usage; exit 1 ;;
    esac
done


if [[ -s $included_tests_file ]]; then
    INCLUDED_TESTS=$(filter_comments $included_tests_file)
    INCLUDED_TESTS_REGEX=$(array_to_regex ${INCLUDED_TESTS[@]})
else
    echo "included-tests file $included_tests_file does not exist or is empty"
    exit 1
fi

if [[ -s $excluded_tests_file ]]; then
    EXCLUDED_TESTS=$(filter_comments $excluded_tests_file)
    EXCLUDED_TESTS_REGEX=$(array_to_regex ${EXCLUDED_TESTS[@]})
else
    echo "WARNING: excluded-tests file $excluded_tests_file does not exist or is empty, no tests will be excluded"
    EXCLUDED_TESTS_REGEX="^no_exclude"
fi

if [[ -s $isolated_tests_file ]]; then
    ISOLATED_TESTS=$(filter_comments $isolated_tests_file)
    ISOLATED_TESTS_REGEX=$(array_to_regex ${ISOLATED_TESTS[@]})
else
    echo "WARNING: isolated-tests file $isolated_tests_file does not exist or is empty, no tests will run isolated"
    ISOLATED_TESTS_REGEX="^no_isolated"
fi


pushd /opt/stack/tempest

if [ ! -d ".stestr" ]; then
    echo "Initializing stestr"
    stestr init
fi

# install all dependencies
tox -eall-plugin --notest

ALL_TESTS=$(stestr list)
if [ $? -ne 0 ];then
    echo "Error while listing tests"
    exit 1
fi


echo "$ALL_TESTS" | grep -E "$INCLUDED_TESTS_REGEX" | grep -vE "$EXCLUDED_TESTS_REGEX" | grep -vE "$ISOLATED_TESTS_REGEX" | sed -e 's/\[[^][]*\]//g' > $TEMPEST_LOGS_FOLDER/parallel-testlist.txt
stestr run --concurrency=8 --whitelist-file $TEMPEST_LOGS_FOLDER/parallel-testlist.txt
stestr last --subunit > $TEMPEST_LOGS_FOLDER/subunit.output

if [ "$ISOLATED_TESTS_REGEX" != "^no_isolated" ];then
    echo "$ALL_TESTS" | grep -E "$ISOLATED_TESTS_REGEX" | sed -e 's/\[[^][]*\]//g' > $TEMPEST_LOGS_FOLDER/isolated-testlist.txt
    stestr run --serial --whitelist-file $TEMPEST_LOGS_FOLDER/isolated-testlist.txt
    stestr last --subunit >> $TEMPEST_LOGS_FOLDER/subunit.output
fi

#subunit-stats $TEMPEST_LOGS_FOLDER/subunit.output > /dev/null
#test_result=$?
# retry failed tests as isolated
#if [ $test_result -ne 0 ];then
#    echo "The following tests failed, retrying them isolated"
#    cat $TEMPEST_LOGS_FOLDER/subunit.output | subunit-filter --failure --no-skip | subunit-ls | sed -e 's/\[[^][]*\]//g' | tee $TEMPEST_LOGS_FOLDER/retry-testlist.txt
    # remove failed tests from subunit.output because we add them again after retry
#    cat $TEMPEST_LOGS_FOLDER/subunit.output | subunit-filter -efs > $TEMPEST_LOGS_FOLDER/subunit.tmp
#    mv $TEMPEST_LOGS_FOLDER/subunit.tmp $TEMPEST_LOGS_FOLDER/subunit.output
#    tox -eall-plugin -- ".*" --serial --combine --whitelist-file $TEMPEST_LOGS_FOLDER/retry-testlist.txt
#    testr last --subunit >> $TEMPEST_LOGS_FOLDER/subunit.output
#fi

subunit2html $TEMPEST_LOGS_FOLDER/subunit.output $TEMPEST_LOGS_FOLDER/subunit.html
subunit-stats $TEMPEST_LOGS_FOLDER/subunit.output > $TEMPEST_LOGS_FOLDER/subunit.stats
exit_code=$?

popd

echo "Exit code: $exit_code"
exit $exit_code
