# (Advanced) Subst(itution with completion) (Vim) 

This plugin add features:
* substitution with options at the end :
     * options g,n,c,I,#,p,n,e,i,& have same meaning that in s///opt
     * option % and 2,4 will work as range
     * option h to add in history
     * option v to revert src & dest
     * option f or ~ for a fuzzy substitution
     * option x to exchange values instead of substitute
       Note : with x option, regexp are not supported
* command arguments are completed in wildmode (include tags)

# Usage
```vim
" Search
:S pattern
" Substitute
:S pattern replacement options
" Search  (SQ is for Quoted Search/Subst, simple and double quote are useable)
:SQ 'pattern'
" Substitute
:SQ 'pattern','replacement','options'
```
