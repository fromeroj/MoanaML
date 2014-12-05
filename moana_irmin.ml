(*
* Copyright (c) 2014 Yan Shvartzshnaider
*
* Permission to use, copy, modify, and distribute this software for any
* purpose with or without fee is hereby granted, provided that the above
* copyright notice and this permission notice appear in all copies.
*
* THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
* WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
* MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
* ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
* WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
* ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
* OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
*)


(* Irmin based storage *)
open Moana
  
open Lwt
  
open Irmin_unix
  
open Config
  
module Git =
  IrminGit.FS(struct let root = Some "/tmp/irmin/moana"

                        let bare = true
                           end)
  
(* Values are Strings * *)
module Store = Git.Make(IrminKey.SHA1)(IrminContents.String)(IrminTag.String)
  
module TupleView =
  struct
    type t2 = Config.tuple
    
    type t = t2 list
    
    (* create list of tuples from view *)
    let t_of_view v =
      let aux acc i =
        let i = string_of_int i
        in
          (Store.View.read_exn v [ i ]) >>=
            (fun x -> return ((Helper.from_json x) :: acc))
      in
        (Store.View.list v [ [] ]) >>=
          (fun key_list ->
             let keys =
               List.map
                 (function | [ i ] -> int_of_string i | _ -> assert false)
                 key_list
             in Lwt_list.fold_left_s aux [] keys)
      
    (* create view from list of tuples *)
    let view_of_t tuples =
      (Store.View.create ()) >>=
        (fun v ->
           (Lwt_list.iteri_s
              (fun i tuple ->
                 let i = string_of_int i
                 in
                   (* let p=print_endline (Yojson.Basic.to_string (to_json  *)
                   (* () tpl)) in                                           *)
                   Store.View.update v [ i ]
                     (Yojson.Basic.to_string (Helper.to_json tuple)))
              tuples)
             >>=
             (fun () -> (*print_tuples (Lwt_unix.run (t_of_view v));*)
                return v))
      
  end
  
module S : STORE =
  struct
    open TupleView
      
    type t = Store.t
    
    let name = "IrminStore"
      
    let empty = Lwt_unix.run (Store.create ())
      
    let init tuples =
      Lwt_unix.run
        ((Store.create ()) >>=
           (fun t ->
              (TupleView.view_of_t tuples) >>=
                (fun view ->
                   (Store.View.update_path t [ "Tuples" ] view) >>=
                     (fun () ->
                        (* Store.View.of_path t ["Tuples"] >>= fun v ->    *)
                        (* print_tuples (Lwt_unix.run (t_of_view v));      *)
                        return t))))
      
    (* add tuple view to the storage *)
    let add storage tuple =
      Lwt_unix.run
        ((Store.View.of_path storage [ "Tuples" ]) >>=
           (fun v ->
              (TupleView.t_of_view v) >>=
                (fun list ->
                   (return (tuple :: list)) >>=
                     (fun new_list ->
                        (TupleView.view_of_t new_list) >>=
                          (fun new_view ->
                             (Store.View.update_path storage [ "Tuples" ]
                                new_view)
                               >>= (fun _ -> return storage))))))
      
    let query (store : t) (q : Config.tuple list) =
      Lwt_unix.run
        ((Store.View.of_path store [ "Tuples" ]) >>=
           (fun v ->
              (TupleView.t_of_view v) >>=
                (fun list -> return (Config.execute_query list q))))
      
    let to_list t =
      Lwt_unix.run
        ((Store.View.of_path t [ "Tuples" ]) >>=
           (fun v -> TupleView.t_of_view v))
      
  end
  
(* Moana GRAPH with List storage as a backend *)
module G : GRAPH =
  struct
    module IS = S
      
    type t = IS.t
    
    let init = IS.init
		
		let graph = IS.empty
      
    let add g (tuple : Config.tuple) =
      let s =
        Printf.sprintf "Adding fact to [ %s <- %s ]" IS.name
          (Helper.to_string tuple)
      in (print_endline s; IS.add g tuple)
      
    let map g (query : Config.tuple list) = 			
			IS.query g query 
      
       
  end
  
