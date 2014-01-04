# [SHALMANESER - a SHALlow seMANtic parSER](http://www.coli.uni-saarland.de/projects/salsa/shal/)


[RubyGems](http://rubygems.org/gems/shalmaneser) | [Shalmanesers Project Page](http://bu.chsta.be/projects/shalmaneser/) |
[Source Code](https://github.com/arbox/shalmaneser) | [Bug Tracker](https://github.com/arbox/shalmaneser/issues)

[<img src="https://badge.fury.io/rb/shalmaneser.png" alt="Gem Version" />](http://badge.fury.io/rb/shalmaneser)
[<img src="https://travis-ci.org/arbox/shalmaneser.png" alt="Build Status" />](https://travis-ci.org/arbox/shalmaneser)
[<img src="https://codeclimate.com/github/arbox/shalmaneser.png" alt="Code Climate" />](https://codeclimate.com/github/arbox/shalmaneser)
[<img alt="Bitdeli Badge" src="https://d2weczhvl823v0.cloudfront.net/arbox/shalmaneser/trend.png" />](https://bitdeli.com/free)
[![Dependency Status](https://gemnasium.com/arbox/shalmaneser.png)](https://gemnasium.com/arbox/shalmaneser)

## Description

Please be careful, the whole thing is under construction!

Shalmaneser is a supervised learning toolbox for shallow semantic parsing, i.e. the automatic assignment of semantic classes and roles to text. The system was developed for Frame Semantics; thus we use Frame Semantics terminology and call the classes frames and the roles frame elements. However, the architecture is reasonably general, and with a certain amount of adaption, Shalmaneser should be usable for other paradigms (e.g., PropBank roles) as well. Shalmaneser caters both for end users, and for researchers.

For end users, we provide a simple end user mode which can simply apply the pre-trained classifiers for English (FrameNet annotation / Collins parser) and German (SALSA Frame annotation / Sleepy parser). For researchers interested in investigating shallow semantic parsing, our system is extensively configurable and extendable.

## Origin
You can find original versions of Shalmaneser up to ``1.1`` on the [SALSA](http://www.coli.uni-saarland.de/projects/salsa/shal/) project page.

## Publications on Shalmaneser

K. Erk and S. Padó: Shalmaneser - a flexible toolbox for semantic role assignment. Proceedings of LREC 2006, Genoa, Italy. [Click here for details](http://www.nlpado.de/~sebastian/pub/papers/lrec06_erk.pdf).

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

