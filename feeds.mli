type append_state = Ok | Not_connected | Empty | Already_exist

val to_html : unit -> (([> Html5_types.p ] Html.elt) list) Lwt.t
val to_atom : unit -> Atom_feed.feed Lwt.t
val append_feed : (string * string) -> append_state Lwt.t
