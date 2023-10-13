create database vendingMachine;

create schema customer;
create schema items;
create schema utils;

create table items.items(
  id serial primary key ,
  price decimal,
  item_name varchar,
  quantity int check ( quantity>=0) default 20
);
drop table items.items;

INSERT INTO items.items (price, item_name, quantity) VALUES (10.99, 'Item 1',2);
INSERT INTO items.items (price, item_name) VALUES (15.50, 'Item 2');
INSERT INTO items.items (price, item_name) VALUES (8.75, 'Item 3');

select * from items.items;
create table customer.customer(
    id serial primary key ,
    username varchar unique not null ,
    balance decimal check (balance>0)
);
INSERT INTO customer.customer (username, balance) VALUES ('user123', 100.00);
INSERT INTO customer.customer (username, balance) VALUES ('testuser', 50.00);
INSERT INTO customer.customer (username, balance) VALUES ('exampleuser', 200.00);
select * from customer.customer;



create procedure customer.buy_something(itemId int , userId int) language plpgsql
as
$$
    declare
        t_user record;
        t_item record;
    BEGIN
        select * into t_user from customer.customer c where userId = c.id;
        if not FOUND then
            raise exception 'User not found!';
        end if;
        select * into t_item from items.items i where itemId = i.id;
        if not FOUND then
            raise exception 'Item not found!';
        end if;
        if t_item.quantity=0 then
            raise exception 'Sorry but % is not left', t_item.item_name;
        end if;
        update customer.customer set balance = balance - t_item.price where customer.id = userId;
        update items.items set quantity = quantity - 1 where t_item.id = itemId;
    end;
$$;
drop procedure buy_something(itemId int, userId int);

create function customer.addBalance(userId int , amount decimal) returns int language plpgsql
as
$$
    declare
        t_user record;

    BEGIN
        select * into t_user from customer.customer c where c.id = userId;
        if not FOUND then
            raise exception 'User not found!';
        end if;
        update customer.customer c set balance = balance + amount where c.id = userId;
        return t_user.balance;
    end;
$$;
set search_path to customer;

create function items.add_items(itemId int , quantity_of_items int) returns int language plpgsql
as
$$
    declare t_item record;
    BEGIN
         select * into t_item from items.items i where i.id = itemId;
         if not FOUND then
             raise exception 'Item id not found!';
         end if;
         update items.items set quantity = quantity + quantity_of_items where id = itemId;
         return t_item.quantity;
    end;
$$;


--TESTING!!!

select * from items.items;
select * from customer.customer;

select addbalance(1,100); -- working!!!

set search_path to items;
set search_path to customer;
select items.add_items(1,30);
call customer.buy_something(1,1);



