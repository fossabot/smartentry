#!/bin/bash

[[ $DEBUG == true ]] && set -x

case ${1} in
    build)
        if [[ -n $MD5_CHECKLIST ]] ; then
            cd $TEMPLATES_DIR
            find . -mindepth 1 -type d | while read dir; do mkdir -p ${dir#*.} ; done
            TEMPLATE_VARIABLES=$(find . -type f -exec grep -P -o '(?<={{).+?(?=}})' {} \; | xargs -n 1 echo | sort | uniq ) 
            find . -type f | 
            while read file; do
                md5sum ${file#*.} >> $MD5_CHECKLIST
            done
        fi
        if [[ -n $ATTRIBUTE_FIX_LIST ]] && [[ $ATTRIBUTE_AUTO_FIX_ENABLE != false ]]; then
            cd $TEMPLATES_DIR 
            find . -type f |
            while read file; do
                stat -c "%a	%U	%G	$(realpath $file)" $file >> ${ATTRIBUTE_FIX_LIST}.add
            done
            cat ${ATTRIBUTE_FIX_LIST} >> ${ATTRIBUTE_FIX_LIST}.add
            mv ${ATTRIBUTE_FIX_LIST}.add ${ATTRIBUTE_FIX_LIST}
        fi
        ;;
    *)
        [[ -f $DEFAULT_ENV ]] && source $DEFAULT_ENV

        cd $TEMPLATES_DIR
        find . -mindepth 1 -type d | while read dir; do mkdir -p ${dir#*.} ; done
        TEMPLATE_VARIABLES=$(find . -type f -exec grep -P -o '(?<={{).+?(?=}})' {} \; | xargs -n 1 echo | sort | uniq)
        find . -type f | 
        while read file; do
            file_dst=${file#*.}
            if [[ -f $MD5_CHECKLIST ]]; then
                cat $MD5_CHECKLIST | grep $file_dst | md5sum -c --quiet > /dev/null 2>&1 && cp $file $file_dst ;
                [[ ! -f $file_dst ]] && cp $file $file_dst ;
            else
                cp $file $file_dst ;
            fi
            [[ -n $TEMPLATE_VARIABLES ]] && echo $TEMPLATE_VARIABLES | xargs -n 1 echo | 
            while read variable; do
                [[ -n $variable ]] && eval sed -i "s/{{$variable}}/\${$variable}/g" $file_dst ;
            done
        done

        [[ -f $ATTRIBUTE_FIX_LIST ]] && cat $ATTRIBUTE_FIX_LIST | awk '{ printf("chmod %s %s\n",$1,$4); }' | sh
        [[ -f $ATTRIBUTE_FIX_LIST ]] && cat $ATTRIBUTE_FIX_LIST | awk '{ printf("chown %s:%s %s\n",$2,$3,$4); }' | sh

        exec "$@"
        ;;
esac