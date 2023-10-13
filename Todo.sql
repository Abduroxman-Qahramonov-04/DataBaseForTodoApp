create database todoApp;
--AUTH
create schema auth;
create schema todo;
create schema category;
create schema utils;

set search_path to auth;

create type authrole as enum('USER','ADMIN');
create type language as enum ('UZ','RU','EN');

create table authuser(
    id serial primary key,
    username varchar unique not null,
    constraint username_length_valid_check
    check ( length(username)>4),
    password varchar not null,
    role authrole default 'USER' not null,
    ln language ,
    created_at timestamp default current_timestamp not null
);
drop table auth.authuser;

create function auth_register(uname varchar,pswd varchar, lnM text) returns int language plpgsql
as
$$
    declare
        languageMode text;
        newId int;
        t_auth_user record;
    BEGIN
        select * into t_auth_user from auth.authuser a where a.username ilike uname;
    case
        when lnM = 'UZ' then
        languageMode := 'Username allaqachon ishlatilgan!';
        when lnM = 'RU' then
        languageMode := 'Имя пользователя уже использовано!';
        when lnM = 'EN' then
        languageMode := 'Username has already been used!';
        else
        raise exception 'Sorry but we do not support this language yet!';
    end case;

    if found then
        raise exception '%', languageMode;
    end if;
    insert into auth.authuser (username, password,ln)
    values (uname, utils.encode_password(pswd),lnM::language) returning id into newId;
    return newId;
    end
$$;
drop function auth.auth_register(uname varchar, pswd varchar,ln text);
set search_path to auth;
select auth.auth_register('user1','2342','EN');
select auth.auth_register('user2','234','RU');
select auth.auth_register('user3','2342','EN');
select auth.auth_register('user4','234','UZ');
select auth.auth_register('user5','2342','UZ');
select auth.auth_register('user6','234','RU');

select * from auth.authuser;

set search_path to utils;
set search_path  to auth;
create extension pgcrypto;

create function encode_password(raw_password varchar) returns varchar language plpgsql
as
$$
    BEGIN
        return utils.crypt(raw_password,utils.gen_salt('bf',4));
    end;
$$;

create function match_password(raw_password varchar,encoded_password varchar) returns boolean language plpgsql
as
$$
    DECLARE
    BEGIN
        return encoded_password = utils.crypt(raw_password,encoded_password);
    end;
$$;


create function auth_login(uname varchar,pswd varchar, lnM language) returns text language plpgsql
as
$$
    declare
        t_authuser record;
        languageMode text;
    BEGIN
        select * into t_authuser from auth.authuser where username = lower(uname);
        call auth.isactive(t_authuser.id,lnM);
        case
            when lnM = 'UZ' then
            languageMode := 'Notog''ri Parol';
            when lnM = 'RU' then
            languageMode := 'Неверный пароль!';
            when lnM = 'EN' then
            languageMode := 'Password incorrect!';
            else
            raise exception 'Sorry but we do not support this language yet!';
        end case;
        if not utils.match_password(pswd,t_authuser.password) then
            raise exception '%',languageMode;
        end if;
        return json_build_object(
            'id',t_authuser.id,
            'username',t_authuser.username,
            'role',t_authuser.role,
            'create_at',t_authuser.created_at,
            'language',t_authuser.ln
            ) :: text;

    end
$$;
drop procedure auth.isactive(userid int,lnM language);
drop function auth_login(uname varchar, pswd varchar,lnM language);

create procedure auth.isactive(userid int,lnM language) language plpgsql as
$$
    declare
        languageMode text;
    BEGIN
         case
        when lnM = 'UZ' then
        languageMode := 'Foydalanuvchi nomi mavjud emas!';
        when lnM = 'RU' then
        languageMode := 'Имя пользователя не существует!';
        when lnM = 'EN' then
        languageMode := 'Username does not exist!';
        else
        raise exception 'Sorry but we do not support this language yet!';
    end case;
        if not exists(select * from auth.authuser a where a.id = userid) then
            raise exception '%',languageMode;
        end if;
    end;
$$;



select auth_login('user6','234','EN');

create function auth.hasRole(role auth.authrole,userid int) returns boolean language plpgsql as
$$
    declare t_authUser record;
    BEGIN
     select * into t_authUser from  auth.authuser a where a.id = userid;
     if FOUND then
         return t_authUser.role = role;
     else
         return false;

     end if;
    end;
$$;



-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
-- Category

set search_path to category;

create table category(
    id serial primary key ,
    title varchar not null ,
    user_id int not null ,
    created_at timestamp default current_timestamp not null ,
    foreign key (user_id) references auth.authuser(id) on delete cascade
);

create function create_category(title varchar,session_userid int) returns int
language plpgsql
as
$$
    declare
        t_authuser record;
        newId int;
    BEGIN
        call auth.isactive(session_userid,'UZ');

        insert into category.category(title, user_id) values (title,session_userid)
        returning id into newId;
        return newId;

end;
$$;

create function delete_category(category_id int,session_userid int) returns boolean
language plpgsql
as
$$
    declare
        t_authuser record;
        t_category record;
        categoryMode text;
        permissionMode text;

    BEGIN
        call auth.isactive(session_userid,'EN'::auth.language);
        select * into t_authuser from auth.authuser a where a.id = session_userid;
        select *  into t_category from category.category c where c.id = category_id;

        case
        when t_authuser.ln = 'UZ' then
        categoryMode := 'Bunday kategoriya mavjud emas!';
        permissionMode := 'Ruxsat berilmadi!';
        when t_authuser.ln = 'RU' then
        permissionMode := 'Доступ запрещен!';
        categoryMode := 'Категория не найдена!';
        when t_authuser.ln = 'EN' then
        permissionMode := 'Permission denied!';
        categoryMode := 'Category not found!';
        else
        raise exception 'Sorry but we do not support this language yet!';
    end case;

        if not FOUND then
            raise exception '%',categoryMode;
        end if;
        if auth.hasRole('ADMIN',session_userid) or  session_userid = t_category.user_id then
            delete from category.category c where c.id = category_id;
        else
            raise exception '%',permissionMode;
        end if;

        return true;


end;
$$;


drop function delete_category(category_id int, session_userid int);
drop function create_category(title varchar, session_userid int);

select * from category;
select * from auth.authuser;



select category.create_category('Category 3',5);

set search_path to category;

select category.delete_category(16,5);

--!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
--TODO_process

set search_path to todo;

create type priority as enum ('LOW','MEDIUM','HIGH','DEFAULT');

create table todo(
    id serial primary key ,
    title varchar not null ,
    description varchar,
    priority todo.priority default 'DEFAULT',
    category_id int ,
    created_at timestamp default current_timestamp not null,
    due_date date,
    foreign key (category_id) references category.category(id)

);
drop table todo;

create function create_todo(dataparam text, userid int)
returns int language plpgsql
as
$$
    declare
        dataJson json;
        newId int;
        v_priority todo.priority;
        v_due_date date;
        t_category record;
    BEGIN
        call auth.isactive(userid,'EN');
        if dataparam is null then
            raise exception 'Dataparam invalid';
        end if;
        dataJson := dataparam::json;

        select * into t_category from category.category c where c.id = (dataJson->>'category_id')::int;

        if not FOUND then
            raise exception 'category not found %',(datajson->>'category_id');
        end if;

        if t_category.user_id <> userid then
            raise exception 'Permission denied';
        end if;

        if dataJson->>'priority' is null then
            v_priority := 'DEFAULT';
        else
            v_priority := dataJson->>'priority';
        end if;

        if not (dataJson->>'due_date' is null) then
            v_due_date = (dataJson->>'due_date')::date;

        end if;


        insert into todo.todo(title, description, priority, category_id, due_date)
        values (
                dataJson->>'title',
                dataJson->>'description',
                v_priority,
                (dataJson->>'category_id')::int,
                (dataJson->>'due_date')::date
               )
        returning id into newId;
        return newId;



    end;

$$;
drop function create_todo(dataparam text, userid integer);

select create_todo('{
  "title": "some title",
  "category_id": 12,
  "description": "Something in description",
  "due_date": "2023-03-28",
  "priority": "LOW" ,
   "is_done": "false"
}',20);
select * from auth.authuser;
select * from category.category;
select * from todo;


alter table todo add column is_done boolean default false not null ;


create function update_todo(dataparam varchar ,userid int) returns boolean
language plpgsql
as
$$
    declare
        t_todo record;
        dataJson json;
        dto todo.update_todo_dto;
        v_priority todo.priority;
        t_category record;
    BEGIN
        call auth.isactive(userid,'RU');
        if dataparam is null then
            raise exception 'Datapram invalid';
        end if;

        dataJson := dataparam::json;
        dto.id := dataJson->> 'id';

        select * into t_todo from todo.todo t where t.id = dto.id;

        if not FOUND then
            raise exception 'Todo not found';
        end if;

        select * into t_category from category.category c where c.id = t_todo.category_id;

        if not FOUND OR t_category.user_id<>userid then
            raise exception 'Permission denied';
        end if;

        if not (dataJson->>'priority' is null) then
            v_priority := dto.priority::priority;
        else
            v_priority := t_todo.priority;
        end if;


        dto.title := coalesce(dataJson ->> 'title',t_todo.title);
        dto.description := coalesce(dataJson ->> 'description',t_todo.description);
        dto.due_date := coalesce(dataJson ->> 'due_date',(t_todo.due_date)::text);
        dto.is_done := coalesce(dataJson ->> 'is_done',(t_todo.is_done)::text);

        update todo.todo
            set title = dto.title,
            description = dto.description,
            priority = v_priority,
            due_date = dto.due_date,
            is_done = dto.is_done
        where id = dto.id;

        return true;
    END;

$$;

drop function update_todo(dataparam varchar, userid integer);

create type update_todo_dto as(
        id int,
        title varchar,
        description varchar,
        priority todo.priority,
        category_id int,
        due_date date,
        is_done boolean
);

select * from todo;
select update_todo('{
  "id": 3,
  "title": "last try",
  "description": "tatakae",
  "due_date": "2025-03-11",
  "priority": "HIGH",
  "is_done": true
}' ,20);

select * from auth.authuser;

create function user_todos_by_category(userid int) returns text
language plpgsql
as
$$
    declare
    BEGIN
        call auth.isactive(userid,'EN');
        return (select json_agg( json_build_object(
            'category_id',category_id,
            'category_name',category_name,
            'user_id', user_id,
            'todos',todos
            ))
        from (select category_id,c.title category_name,c.user_id, json_agg(
            json_build_object(
                'id',t.id,
                'title',t.title,
                'description',t.description,
                'due_date',t.due_date,
                'priority',t.priority,
                'is_done',t.is_done,
                'created_at',t.created_at
                )
            ) todos
            from todo t
            inner join category.category c on c.id = t.category_id
            where c.user_id = userid
            group by t.category_id,c.title,c.user_id) as category_details)::text;
    END;
$$;

drop function user_todos_by_category(userid int);
select user_todos_by_category(20);