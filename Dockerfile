# FROM ruby:3.0.2 #hitting dockerhub limits
# FROM public.ecr.aws/i7t6p8u9/ubuntu20_ruby3.0.2:latest
FROM public.ecr.aws/bitnami/ruby:3.0.2


ENV PATH /root/.yarn/bin:$PATH

ARG build_without
ARG rails_env
RUN apt-get update -qq && apt-get install -y binutils curl git gnupg cmake python python-dev postgresql-client libpq-dev supervisor tar tzdata
RUN apt-get install -y apt-transport-https apt-utils
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - && apt-get install -y nodejs
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update && apt-get install -y yarn
RUN mkdir /rails_terraform_docker
COPY . /rails_terraform_docker
WORKDIR /rails_terraform_docker

RUN gem install bundler -v 2.0.2

# RUN bundle config build.pg --with-pg-lib=/opt/bitnami/postgresql/lib
RUN bundle install 
RUN yarn install

RUN RAILS_ENV=production NODE_ENV=production SECRET_KEY_BASE=not_set OLD_AWS_SECRET_ACCESS_KEY=not_set OLD_AWS_ACCESS_KEY_ID=not_set bundle exec rake assets:precompile

# Add a script to be executed every time the container starts.
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
EXPOSE 3000

# Start the main process.
CMD ["rails", "server", "-b", "0.0.0.0"]