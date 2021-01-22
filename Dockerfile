FROM ubuntu

RUN apt update
RUN apt install software-properties-common -y
RUN add-apt-repository ppa:inkscape.dev/stable -y
RUN apt update
RUN apt install wget -y
RUN apt install libimage-exiftool-perl -y
RUN apt install default-jre openjdk-11-jre-headless -y
RUN apt install zip -y
RUN apt install texlive-extra-utils -y
RUN apt install inkscape -y

WORKDIR /usr/ThreatDeck

ENTRYPOINT ["./build.sh"]