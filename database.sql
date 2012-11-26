/******************************************************************************
* Copyright (C) 2012 Renato "Lond" Cerqueira                                  *
*                                                                             *
* This file is part of filmow-friends.                                        *
*                                                                             *
* filmow-friends is free software: you can redistribute it and/or modify      *
* it under the terms of the GNU General Public License as published by        *
* the Free Software Foundation, either version 3 of the License, or           *
* (at your option) any later version.                                         *
*                                                                             *
* filmow-friends is distributed in the hope that it will be useful,           *
* but WITHOUT ANY WARRANTY; without even the implied warranty of              *
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the               *
* GNU General Public License for more details.                                *
*                                                                             *
* You should have received a copy of the GNU General Public License           *
* along with filmow-friends.  If not, see <http://www.gnu.org/licenses/>.     *
******************************************************************************/

create table users ( id integer primary key, name text, login text, last_cached integer, movies_count integer );

create table movies ( id integer primary key, title text, img text, link text unique, html text );

create table users_movies ( id integer primary key, users_id integer, movies_id integer );

