module Calendar = CalendarLib.Calendar

type append_state = Ok | Not_connected | Empty | Already_exist | Invalid_url

type 'a tree =
  | Sheet of 'a
  | Node of 'a * 'a tree list

let rec get_tree_feeds feed comments =
  match (Feed.get_comments_of_feed feed comments) with
    | [] -> Sheet feed 
    | l -> Node (feed, List.map (fun x -> get_tree_feeds x (Feed.get_others_of_feed feed comments)) l)

let feeds_of_db feeds =
  Lwt.return
    (List.map
       (fun feed ->
         Feed.feed_new
           feed
           (List.map
              (fun elm -> elm#!tag)
              (List.filter (fun elm -> elm#!id_feed = feed#!id) (snd feeds))
           )
       )
       (fst feeds)
    )

let to_somthing f data =
  Lwt_list.map_p (fun feed -> f feed) data

let private_to_html data =
  to_somthing
    (fun feed ->
      Feed.to_html feed >>= (fun elm ->
        Lwt.return (Html.div ~a: [Html.a_class ["line post"]] elm)
      )
    ) data

let get_comments id =
  Db.get_feed_with_id id
  >>= feeds_of_db
  >>= (fun root ->
  Db.get_comments id
  >>= feeds_of_db
  >>= (fun comments ->
    Lwt.return (get_tree_feeds (List.hd root) comments)
  ))

let author_to_html ~starting author =
  Db.get_feeds_with_author ~starting author
  >>= feeds_of_db
  >>= private_to_html

let tag_to_html ~starting tag =
  Db.get_feeds_with_tag ~starting tag
  >>= feeds_of_db
  >>= private_to_html

let root_to_html ~starting () =
  Db.get_root_feeds ~starting ()
  >>= feeds_of_db
  >>= private_to_html

let to_html ~starting () =
  Db.get_feeds ~starting ()
  >>= feeds_of_db
  >>= private_to_html

let feed_id_to_html id =
  Db.get_feed_with_id id
  >>= feeds_of_db
  >>= private_to_html

(* FIXME? should atom feed return only a limited number of links ? *)
let to_atom () =
  Db.get_feeds ~number:100l ()
  >>= feeds_of_db
  >>= to_somthing Feed.to_atom
  >>= (fun tmp ->
    Lwt.return (
      Atom_feed.feed
        ~updated: (Calendar.make 2012 6 9 17 40 30)
        ~id: (Html.Xml.uri_of_string "http://cumulus.org")
        ~title: (Atom_feed.plain "An Atom flux")
        tmp
    )
  )

let (event, private_event, call_event) =
  let (private_event, call_event) = React.E.create () in
  let event = Eliom_react.Down.of_react private_event in
  (event, private_event, call_event)

let append_feed (url, (description, tags)) =
  User.get_userid () >>= fun userid ->
  match userid with
    | None -> Lwt.return Not_connected
    | (Some author) ->
      if (Utils.string_is_empty description || Utils.string_is_empty tags) then
        Lwt.return Empty
      else if Utils.is_invalid_url url then
        Lwt.return Invalid_url
      else
        Db.get_feed_url_with_url url >>= function
          | (Some _) -> Lwt.return Already_exist
          | None ->
            Db.add_feed
              url
              description
              (List.map (fun x -> String.lowercase (Utils.strip x)) (Str.split (Str.regexp "[,]+") tags))
              author >>= fun () ->
            call_event ();
            Lwt.return Ok
