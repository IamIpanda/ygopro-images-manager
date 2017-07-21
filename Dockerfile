FROM ruby

RUN dpkg --add-architecture i386
RUN apt-get update
RUN apt-get install -y wine imagemagick

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

# RUN git config --global user.email "zh99998+mycard@gmail.com"
# RUN git config --global user.name "mycard"
# RUN git config --global push.default simple
# RUN ssh-keyscan github.com > /etc/ssh/ssh_known_hosts

ENV WINEARCH=win32
ENV RACK_ENV=production
RUN wineboot -i
COPY magicseteditor/fonts /root/.wine/drive_c/windows/Fonts

COPY . /usr/src/app
COPY Gemfile /usr/src/app/
COPY Gemfile.lock /usr/src/app/
RUN bundle config --global frozen 1
RUN bundle install

RUN git submodule update --recursive
ENTRYPOINT ruby /usr/src/app/entrypoint.rb