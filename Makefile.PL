use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
              'NAME'		=> 'Macro',
              'VERSION_FROM'	=> 'Macro.pm',
              'PREREQ_PM'       => {},
              'PM'              => { 'Simple.pm' => '$(INST_LIBDIR)/Filter/Simple.pm',
                                     'RecDescent.pm' => '$(INST_LIBDIR)/Parse/RecDescent.pm',
                                     'Macro.pm' => '$(INST_LIBDIR)/Macro.pm' },
              'HTMLLIBPODS'     => { 'Macro.pod' }
);
