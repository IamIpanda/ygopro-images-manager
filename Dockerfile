FROM ruby

RUN dpkg --add-architecture i386
RUN apt-get update
RUN apt-get install -y wine xvfb imagemagick

RUN bundle config --global frozen 1
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app
COPY Gemfile /usr/src/app/
COPY Gemfile.lock /usr/src/app/
RUN bundle install

RUN git config --global user.email "zh99998+mycard@gmail.com"
RUN git config --global user.name "mycard"
RUN git config --global push.default simple
RUN ssh-keyscan github.com > /etc/ssh/ssh_known_hosts

ENV WINEARCH=win32
ENV RACK_ENV=production
RUN wineboot -i
COPY magicseteditor/fonts /root/.wine/drive_c/windows/Fonts

COPY . /usr/src/app

CMD xvfb-run --server-args="-screen 0 1x0x24" ./Server.rb