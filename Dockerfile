# This file is used to compare changes with "original" version of this gem.
FROM ruby:1.9.3

RUN mkdir /app
COPY . /app
WORKDIR /app

RUN bundle install
RUN gem install appraisal -v 0.5.2
RUN bundle exec rake test
#RUN bundle exec rake appraisal:install
#CMD bundle exec rake appraisal test

