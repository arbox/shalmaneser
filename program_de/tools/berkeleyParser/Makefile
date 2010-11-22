JAVAC = /usr/bin/javac
JAVAFLAGS = -O -d classes

parser:
	mkdir -p classes
	$(JAVAC) $(JAVAFLAGS) edu/berkeley/nlp/*/*.java \
	edu/berkeley/nlp/*/*/*.java
	cd classes ; jar -cfm ../berkley-parser-`date +%Y-%m-%d`.jar ../edu/berkeley/nlp/PCFGLA/manifest.txt edu;
	cd ..
	cp berkley-parser-`date +%Y-%m-%d`.jar berkley-parser.jar
	rm -r classes
