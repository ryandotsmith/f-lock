drop table if exists zones;
create table zones(id serial, name text);

drop table if exists endpoints;
create table endpoints(id serial, name text, uri text);

insert into zones(name) values('shushud-partitioned.net.');

insert into endpoints(name, uri) values(
       'shushu.herokuapp.com',
       'https://1:3796@shushu.herokuapp.com/heartbeat');

insert into endpoints(name, uri) values(
       'shushu.staging.herokuappdev.com',
       'https://1:3796@shushu.staging.herokuappdev.com/heartbeat');
