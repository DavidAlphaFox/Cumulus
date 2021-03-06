(*
Copyright (c) 2012 Enguerrand Decorne

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*)

open Batteries
open Eliom_lib.Lwt_ops

module UTF8 = CamomileLibraryDefault.Camomile.CaseMap.Make(CamomileLibrary.UTF8)

type append_state = Ok | Not_connected | Empty | Already_exist | Invalid_url

let (event, call_event) =
  let (private_event, call_event) = React.E.create () in
  let event = Eliom_react.Down.of_react private_event in
  (event, call_event)

let strip_and_lowercase x =
  (* (List.map (fun x -> String.lowercase (Utils.strip x)) (Str.split (Str.regexp "[,]+") tags)) *)
  UTF8.lowercase (Utils.strip x)

let updating_and_ret () =
  call_event ();
  Lwt.return Ok

let append_feed_aux_base ~description f =
  User.get_userid () >>= function
  | None -> Lwt.return Not_connected
  | Some author ->
      if Utils.string_is_empty description
      then Lwt.return Empty
      else f ~author ()

let append_feed_aux ~url ~description ~tags f =
  append_feed_aux_base ~description
    (fun ~author () ->
       if Utils.string_is_empty tags then
         Lwt.return Empty
       else if Utils.is_invalid_url url then
         Lwt.return Invalid_url
       else
         Db_feed.exists_with_url ~url >>= function
         | true -> Lwt.return Already_exist
         | false -> f ~author () >>= updating_and_ret
    )

let append_feed (url, (description, tags)) =
  append_feed_aux ~url ~description ~tags
    (fun ~author () ->
       Db_feed.add_feed
         ~url
         ~description
         ~tags:(List.map strip_and_lowercase (Utils.split tags))
         ~userid:author
         ()
    )

let get_root_and_parent id =
  User.get_userid () >>= fun user ->
  Db_feed.get_feed_with_id ~user id >>= fun feeds ->
  let parent = feeds.Feed.id in
  let root = match feeds.Feed.root with
    | Some root -> root
    | None -> parent
  in
  Lwt.return (Db_feed.add_feed ~root ~parent)

let append_link_comment (id, (url, (description, tags))) =
  append_feed_aux ~url ~description ~tags
    (fun ~author () ->
       get_root_and_parent id >>= fun f ->
       f ~url
         ~description
         ~tags:(List.map strip_and_lowercase (Utils.split tags))
         ~userid:author
         ()
    )

let append_desc_comment (id, description) =
  append_feed_aux_base ~description
    (fun ~author () ->
       get_root_and_parent id >>= fun f ->
       f ~description
         ~tags:[]
         ~userid:author
         ()
       >>= updating_and_ret
    )

let edit_feed_aux ~id ~url ~description ~tags f =
  User.get_userid () >>= fun user ->
  append_feed_aux_base ~description
    (fun ~author:_ () ->
       if Utils.string_is_empty tags then
         Lwt.return Empty
       else if Utils.is_invalid_url url then
         Lwt.return Invalid_url
       else
         Db_feed.get_feed_with_id ~user id >>= (fun feeds ->
           if feeds.Feed.url <> Some url then
             Db_feed.exists_with_url ~url >>= function
             | true -> Lwt.return Already_exist
             | false -> f () >>= updating_and_ret
           else
             f () >>= updating_and_ret)
    )

let edit_link_comment (id, (url, (description, tags))) =
  edit_feed_aux ~id ~url ~description ~tags
    (fun () ->
       Db_feed.update
         ~feedid:id
         ~url:(Some url)
         ~description
         ~tags:(List.map strip_and_lowercase (Utils.split tags))
         ()
    )

let edit_desc_comment (id, description) =
  append_feed_aux_base ~description
    (fun ~author:_ () ->
       Db_feed.update
         ~feedid:id
         ~description
         ~tags:[]
         ~url:None
         ()
       >>= updating_and_ret
    )
