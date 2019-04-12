formatting tools

clean leading spaces from end of each line -> src https://www.cyberciti.biz/tips/delete-leading-spaces-from-front-of-each-word.html

    grep -lr '[ \t]*$' * | xargs sed -i 's/[ \t]*$//'
