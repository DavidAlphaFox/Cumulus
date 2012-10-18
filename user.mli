type user
type user_state = Already_connected | Ok | Bad_password | Not_found

val user_new :
  < email : < get : 'a; nul : Sql.non_nullable; t : Sql.string_t > Sql.t;
  id : < get : 'b; nul : Sql.non_nullable; t : Sql.int32_t > Sql.t;
  name : < get : 'c; nul : Sql.non_nullable; t : Sql.string_t > Sql.t;
  password : < get : 'd; nul : Sql.non_nullable; t : Sql.string_t > Sql.t;
  is_admin : < get : unit; nul : Sql.non_nullable; t : Sql.bool_t > Sql.t > ->
  user
val add : string -> string -> string -> unit Lwt.t
val get_userid : unit -> (int32 option) Lwt.t
val is_connected : unit -> bool Lwt.t
val is_admin : unit -> bool Lwt.t
val connect : user -> string -> user_state Lwt.t
val disconnect : unit -> bool Lwt.t
val get_login_state : unit -> string Lwt.t
val set_login_state_from_user_state : user_state -> unit Lwt.t
val set_login_state_from_disconnect : bool -> unit Lwt.t
val get_user_and_email : unit ->
  < email: < get : unit; nul : Sql.non_nullable; t : Sql.string_t > Sql.t;
  name : < get : unit; nul : Sql.non_nullable; t : Sql.string_t > Sql.t >
    option Lwt.t
