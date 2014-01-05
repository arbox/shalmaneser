# Shalmaneser Documentation Index

## Prerequisites

You need the following items installed on your system:
- Ruby, at least version 1.7.
- a MySQL database server. The server must be large enough to hold the test data (in end user mode) plus any training data (for training new models in manual mode). For example, training on the complete FrameNet 1.2 dataset requires about 1.5 GB space.
- if you don't want to train classifiers from you own data, you need to download suitable classifiers from our homepage for available configurations.
- preprocessing tools for your language, at least the ones required for the use the pre-trained classifiers. Currently Shalmaneser provides interfaces for the following systems:

<table>
<tr>
<th><em>System</th><th>Version</th>
</tr>
<tr>
<td>TreeTagger</td><td>README from 09.04.96</td>
</tr>
<tr>
<td>Collins Parser</td><td>1.0</td>
</tr>
<tr>
<td>Berkeley Parser</td><td>1.0</td>
</tr>
<tr>
<td>Stanford Parser</td><td>1.0</td>
</tr>
</table>

- at least one machine learning system. Currently Shalmaneser provides interfaces for the following systems:
<table>
<tr>
<th>System</th><th>Version</th>
</tr>
<tr>
<td>TiMBL</td><td>Timbl5</td>
</tr>
<tr>
<td>Mallet</td><td>Mallet 0.4</td>
</tr>
<tr>
<td>OpenNLP MaxEnt</td><td>2.4.0</td>
</tr>
</table>

Note: Please make sure you run the system in a terminal with Unicode encoding (``export LANG=eng_US.UTF-8``).

## Setting up Shalmaneser on your system

### TreeTagger
Downloand the TreeTagger archive from the official [site](http://www.cis.uni-muenchen.de/~schmid/tools/TreeTagger/) by Helmut Schmid, uncompress it to your favorite location, preserve the initial directory structure. The path to the root directory is essential for the experiment file declarations. Schalmaneser expects the following directory structure:

    TreeTaggerRootDirectory
    |_ bin
    |    |_ tree-tagger
    |_ lib
    |    |_ english.par
    |    |_ german.par
    |_ cmd
         |_ filter-german-tags

If you cannot name the binary or the model (the ``.par`` file) as given above please set the following environment variables: ``SHALM_TREETAGGER_BIN`` and ``SHALM_TREETAGGER_MODEL``.


### Berkeley Parser
Downloand the Berkeley Parser archive from the official [site](https://code.google.com/p/berkeleyparser/downloads/list) at Google Code, uncompress it to your favorite location. The path to the root directory is essential for the experiment file declarations. Schalmaneser expects the following directory structure:

    BerkeleyRootDirectory
    |_ berkeleyParser.jar
    |_ grammar.gr

If you cannot name the binary and/or the model as given above please set the following environment variables: ``SHALM_BERKELEY_BIN`` and ``SHALM_BERKELEY_MODEL``.

### Stanford Parser

Downloand the Stanford Parser archive from the official [site](http://nlp.stanford.edu/software/lex-parser.shtml), uncompress it to your favorite location. The path to the root directory is essential for the experiment file declarations. Schalmaneser expects the following directory structure:

    TreeTaggerRootDirectory
    |_ stanford_parser.jar
    |_ stanford_parser-x.y.z-models.jar
