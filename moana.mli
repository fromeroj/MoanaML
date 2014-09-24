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


(* Signature for the STORE backend*)
 
module type STORE =
    sig
      type t 
        
      val db: t
      
      (* storage name *)
      val name : string
        
        
      (*val init_storage: unit*)
      val add : t -> Config.tuple -> t
        
      (* provide a garph-query as list of tuples and returns list of tuples    *)
      (* matching it                                                           *)
      val query :  t -> Config.tuple list -> Config.tuple list
        
      (* return stored graph as set of tuples *)
        
      val to_list: t -> Config.tuple list
        
    end;;
  
(* Signature for the Moana abstraction which will support many type of     *)
(* backend storage.                                                        *)
module type GRAPH =
  sig
          
    (*type tuple*)
      
    type t 
     
    val graph: t     
    (* add fact as a tuple *)
    val add : ?g:t -> Config.tuple -> t
      
    (* specify a query as list of tuple, this will return a matching list of *)
    val map : ?g:t -> Config.tuple list -> Config.tuple list       
          
    val print: t  -> unit
      
  end;;

(* functor to create Moana graph from a give STORE implementation *)

module Make : functor (S:STORE) -> 

sig

  type t = S.t
    
  val graph: t
           
  val add: ?g:t -> Config.tuple -> t
     
          
  val map: ?g:t -> Config.tuple list -> Config.tuple list;;


  val print: t -> unit
  
end;;
