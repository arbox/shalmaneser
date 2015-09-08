# [SHALMANESER - a SHALlow seMANtic parSER](http://www.coli.uni-saarland.de/projects/salsa/shal/)

[RubyGems](http://rubygems.org/gems/shalmaneser) |
[Shalmanesers Project Page](http://bu.chsta.be/projects/shalmaneser/) |
[Source Code](https://github.com/arbox/shalmaneser) |
[Bug Tracker](https://github.com/arbox/shalmaneser/issues)


[![Gem Version](https://img.shields.io/gem/v/shalmaneser.svg")](https://rubygems.org/gems/shalmaneser)
[![Gem Version](https://img.shields.io/gem/v/frprep.svg")](https://rubygems.org/gems/shalmaneser-prep)
[![Gem Version](https://img.shields.io/gem/v/fred.svg")](https://rubygems.org/gems/shalmaneser-fred)
[![Gem Version](https://img.shields.io/gem/v/rosy.svg")](https://rubygems.org/gems/shalmaneser-rosy)


[![License GPL 2](http://img.shields.io/badge/License-GPL%202-green.svg)](http://www.gnu.org/licenses/gpl-2.0.txt)
[![Build Status](https://img.shields.io/travis/arbox/shalmaneser.svg?branch=1.2")](https://travis-ci.org/arbox/shalmaneser)
[![Code Climate](https://img.shields.io/codeclimate/github/arbox/shalmaneser.svg")](https://codeclimate.com/github/arbox/shalmaneser)
[![Dependency Status](https://img.shields.io/gemnasium/arbox/shalmaneser.svg")](https://gemnasium.com/arbox/shalmaneser)

## Description

Please be careful, the whole thing is under construction! For now Shalmaneser it not intended to run on Windows systems since it heavily uses system calls for external invocations.
Current versions of Shalmaneser have been tested on Linux only (other *NIX testers are welcome!).

Shalmaneser is a supervised learning toolbox for shallow semantic parsing, i.e. the automatic assignment of semantic classes and roles to text. This technique is often called SRL (Semantic Role Labelling). The system was developed for Frame Semantics; thus we use Frame Semantics terminology and call the classes frames and the roles frame elements. However, the architecture is reasonably general, and with a certain amount of adaption, Shalmaneser should be usable for other paradigms (e.g., PropBank roles) as well. Shalmaneser caters both for end users, and for researchers.

For end users, we provide a simple end user mode which can simply apply the pre-trained classifiers
for [English](http://www.coli.uni-saarland.de/projects/salsa/shal/index.php?nav=download) (FrameNet 1.3 annotation / Collins parser)
and [German](http://www.coli.uni-saarland.de/projects/salsa/shal/index.php?nav=download) (SALSA 1.0 annotation / Sleepy parser).

We'll try to provide newer pretrained models for English, German, and possibly other languages as soon as possible.

For researchers interested in investigating shallow semantic parsing, our system is extensively configurable and extendable.

## Origin

The original version of Shalmaneser was written by Sebastian Padó, Katrin Erk, Alexander Koller, Ines Rehbein and others during their work in the SALSA Project.

You can find original versions of Shalmaneser up to ``1.1`` on the [SALSA](http://www.coli.uni-saarland.de/projects/salsa/shal/) project page.

## Publications on Shalmaneser

- K. Erk and S. Padó: Shalmaneser - a flexible toolbox for semantic role assignment. Proceedings of LREC 2006, Genoa, Italy. [Click here for details](http://www.nlpado.de/~sebastian/pub/papers/lrec06_erk.pdf).
- TODO: add other works

## Documentation

The project documentation can be found in our [doc](https://github.com/arbox/shalmaneser/blob/1.2/doc/index.md) folder.

## Development

We are working now on two branches:

- ``dev`` - our development branch incorporating actual changes, for now pointing to ``1.2``;

- ``1.2`` - intermediate target;

- ``2.0`` - final target.

## Installation

See the installation instructions in the [doc](https://github.com/arbox/shalmaneser/blob/1.2/doc/index.md#installation) folder.

### Tokenizers

- [Ucto](http://ilk.uvt.nl/ucto/)

### POS Taggers

- [TreeTagger](http://www.cis.uni-muenchen.de/~schmid/tools/TreeTagger/)

### Lemmatizers

- [TreeTagger](http://www.cis.uni-muenchen.de/~schmid/tools/TreeTagger/)

### Parsers

- [BerkeleyParser](https://code.google.com/p/berkeleyparser/downloads/list)
- [Stanford Parser](http://nlp.stanford.edu/software/lex-parser.shtml)
- [Collins Parser](http://www.cs.columbia.edu/~mcollins/code.html)

### Machine Learning Systems

- [OpenNLP MaxEnt](http://sourceforge.net/projects/maxent/files/Maxent/2.4.0/)
- [Mallet](http://mallet.cs.umass.edu/index.php)

## License

See the `LICENSE` file.

## Contributing

See the `CONTRIBUTING` file.
