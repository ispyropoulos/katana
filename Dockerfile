FROM ruby:2.3

RUN apt-get update && apt-get install -y nodejs fontconfig

ENV PHANTOM_JS phantomjs-2.1.1-linux-x86_64

RUN curl  https://bitbucket.org/ariya/phantomjs/downloads/$PHANTOM_JS.tar.bz2 -O -L
RUN tar xvjf $PHANTOM_JS.tar.bz2
RUN mv $PHANTOM_JS /usr/local/share
RUN ln -sf /usr/local/share/$PHANTOM_JS/bin/phantomjs /usr/local/bin

WORKDIR /usr/src/app

CMD rails s -b 0.0.0.0 -p 3000 Puma
