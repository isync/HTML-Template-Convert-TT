use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
	NAME			=> 'HTML::Template::Convert::TT',
	VERSION_FROM		=> 'lib/HTML/Template/Convert/TT.pm', # finds $VERSION
	PREREQ_PM		=> {'HTML::Template' => 2.9, 'Template' => 2.20}, # e.g., Module::Name => 1.1
	($] >= 5.005 ?     ## Add these new keywords supported since 5.005
	(
	ABSTRACT_FROM		=> 'lib/HTML/Template/Convert/TT.pm',
	AUTHOR			=> 'A. D. Solovets <asolovets@gmail.com>') : ()),

	META_MERGE	=> {
		'meta-spec'	=> { version => 2 },
		resources	=> {
			## temporary!!
			repository => {
				url => 'https://github.com/isync/HTML-Template-Convert-TT.git',
				web => 'https://github.com/isync/HTML-Template-Convert-TT',
				type=> 'git',
			},
		},
	},
);
