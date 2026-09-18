$pdf_mode = 4;        # use lualatex
$bibtex_use = 2;      # always run biber, even for cleanup
# --- bib2gls ---
add_cus_dep('aux', 'glstex', 0, 'run_bib2gls');
sub run_bib2gls { return system("bib2gls --group '$_[0]'"); }
push @generated_exts, 'glstex', 'glg';
$clean_ext .= ' %R.glstex %R.glg';