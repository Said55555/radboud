CLEAN_FLAGS=-I ~/clean-2.4/lib/StdLib -nt -lt

CLEAN_FLAGS_GAST=-I ~/clean-2.4/lib/StdLib -I ~/clean-2.4/lib/Gast -I ~/clean-2.4/lib/MersenneTwister -I ~/clean-2.4/lib/Generics -nt
assignment07klinik: assignment07klinik.icl
	clm ${CLEAN_FLAGS_GAST} $@ -o $@

assignment08klinik: assignment08klinik.icl
	clm ${CLEAN_FLAGS_GAST} -h 10M -b $@ -o $@

assignment09klinik: assignment09klinik.icl
	clm ${CLEAN_FLAGS_GAST} -h 10M -b $@ -o $@

exam2011_3: exam2011_3.icl
	clm ${CLEAN_FLAGS_GAST} $@ -o $@

%: %.icl
	clm ${CLEAN_FLAGS} $@ -o $@
