(*
* Copyright (c) 2015 Yan Shvartzshnaider
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
module type Rete =
  sig
    type am
    
    type bm
    
    type t = | Empty | Node of am * bm * t | BNode of Config.tuple list
    
    val join : am -> bm -> bm
      
  end
  
(** AM keeps tuples matching the pattern.
* Each AM also contains vars which is a list of paits (position, var_string)
* position stands for the position of varibale in a pattern and var_string denotes its string value.
* This is used later when we join AM with BM
*
*)
open Config
  	
module InMemory =
  struct
    type am =
      { tuples : tuple list;
        (* for convinience - direct access to tuples without going through variables. *)
        pattern : tuple;
        (* this is a mapping of Variables and their respective values in     *)
        (* each tuple                                                        *)
        vars : (string * (((t element_type) * tuple) list)) list
      }
    
    (* BM contains (var, value, solution for the value *)
		type solutions = { solutions : (string * ((t element_type) * (tuple list))) list}
		
    type bm = |InitBM | BM of solutions 
    
    type t = | Empty | Node of am * bm * t | BNode of Config.tuple list
    
    (* type am = { pattern: tuple; tuples: tuple list; vars: (string *       *)
    (* ((element * tuple) list)) list }                                      *)
    let val_to_json value = let open Rete_node_t
      in
        match value with
        | Variable x -> { t = `Variable; value_ = x; }
        | Constant x -> { t = `Constant; value_ = x; }
      
    let json_to_val jval = let open Rete_node_t
      in
        match jval with
        | { t = `Variable; value_ = x } -> Variable x
        | { t = `Constant; value_ = x } -> Constant x
      
    let get_val value = function | Variable x -> x | Constant x -> x
      
    let tpl_to_json tpl = let open Rete_node_t
      in
        let tpl_json =
          {
            s = val_to_json tpl.subj;
            p = val_to_json tpl.pred;
            o = val_to_json tpl.obj;
            cxt = val_to_json tpl.ctxt;
            time_smp = None;
            sign = None;
          }
        in tpl_json
      
    (* FIXME: take care of time_stp and signature and that issue with context*)
    let json_to_tpl jtpl = let open Rete_node_t
      in
        match jtpl with
        | {
            s = subj;
            p = pred;
            o = obj;
            cxt = ctxt;
            time_smp = ts;
            sign = sg } ->
            {
              subj = json_to_val subj;
              pred = json_to_val pred;
              obj = json_to_val obj;
              ctxt = json_to_val ctxt;
              time_stp = None;
              sign = None;
            }
      
    let to_json_tpl_list tuples = List.map (fun t -> tpl_to_json t) tuples
      
    let to_tpl_list tuples = List.map (fun t -> json_to_tpl t) tuples
      
    let v_json vars =
      List.map
        (fun (var, values) ->
           (var,
            (List.map
               (fun (value, tpl) ->
                  (* (val_to_json value, tpl_to_json tpl) -- we know it's  *)
                  (* constant                                              *)
                  ((get_val () value), (tpl_to_json tpl)))
               values)))
        vars
      
    let json_to_vars vars =
      List.map
        (fun (var, values) ->
           (var,
            (List.map
               (fun (value, tpl) ->
                  (* (val_to_json value, tpl_to_json tpl) -- we know it's  *)
                  (* constant                                              *)
                  ((Constant value), (json_to_tpl tpl)))
               values)))
        vars
      
    let am_to_json am = (* convert the am/vars mapping into json *)
      let open Rete_node_t
      in
        {
          ptrn = tpl_to_json am.pattern;
          tpls = to_json_tpl_list am.tuples;
          vrs = v_json am.vars;
        }
      
    let json_to_am jam = let open Rete_node_t
      in
        {
          pattern = json_to_tpl jam.ptrn;
          tuples = to_tpl_list jam.tpls;
          vars = json_to_vars jam.vrs;
        }
      
    let bm_to_json bm = let open Rete_node_t in
		match bm with
		| InitBM -> {sols = []}
		| BM bm ->	       
        {
          sols =
            List.map
              (fun (var, values) ->
                 match values with
                 | (value, tpls) ->
                     (var, ((get_val () value), (to_json_tpl_list tpls))))
             bm.solutions;
        }
      
   let json_to_bm jbm = let open Rete_node_t
		in
		match jbm with
		| `InitBM -> BM {solutions = []}
		| `BM jbm ->	             
       BM {
          solutions =
            List.map
              (fun (var, values) ->
                 match values with
                 | (value, tpls) ->
                     (var, ((Constant value), (to_tpl_list tpls))))
              jbm;
        }
      
    let rec node_to_json node =
      match node with
      | Node (am, bm, next_node) -> let open Rete_node_t
          in
            `Node ((`AM (am_to_json am)), (`BM (bm_to_json bm)),
              (node_to_json next_node))
      | BNode tuples -> `BNode (to_json_tpl_list tuples)
      | Empty -> `Empty
      
   let rec json_to_node jnode = let open Rete_node_t
      in
        match jnode with
        | `Node ((`AM jam), (`BM jbm), (`Node next_node)) ->
            Node ((json_to_am jam), (json_to_bm jbm),
              (json_to_node next_node))
        | `BNode tuples -> BNode (to_tpl_list tuples)
        | `Empty -> Empty

			let node_json_to_string jnode = 
							 Rete_node_j.string_of_node_json jnode |>    
			              Yojson.Basic.from_string |>Yojson.Basic.pretty_to_string 
			 
    (* helper to filter tuples list to form the pattern *)
    let filter ptrn tuples =
      let cmp p_attr t_attr =
        match p_attr with
        | Variable _ -> true
        | Constant _ -> p_attr = t_attr
      in
        List.filter
          (fun t ->
             (cmp ptrn.subj t.subj) &&
               ((cmp ptrn.pred t.pred) && (cmp ptrn.obj t.obj)))
          tuples
      
    (* add value to the list of values associated with the variable *)
    let sel_arg arg pos =
      match (arg, pos) with
      | (Constant _, _) -> None
      | (Variable var, pos) -> Some (var, pos)
      
    let mappings p tuples =
      List.fold_right
        (fun e acc ->
           match e with
           | Some (var, 1) ->
               acc @ [ (var, (List.map (fun t -> ((t.subj), t)) tuples)) ]
           | Some (var, 2) ->
               acc @ [ (var, (List.map (fun t -> ((t.pred), t)) tuples)) ]
           | (*acc @ [(var, List.map (fun t ->  print_value t.pred; t.pred) tuples)]*)
               Some (var, 3) ->
               acc @ [ (var, (List.map (fun t -> ((t.obj), t)) tuples)) ]
           | Some (_, _) -> acc
           | None -> acc)
        [ sel_arg p.subj 1; sel_arg p.pred 2; sel_arg p.obj 3 ] []
      
    (* helper to print the mappings *)
    let print_mappings am =
      List.map
        (fun (var, values) ->
           (print_string var;
            List.map
              (fun value ->
                 match value with
                 | (Constant x, t) ->
                     (print_endline "";
                      print_string x;
                      print_endline (Helper.to_string t))
                 | (Variable _, _) -> print_string " ")
              values))
        am.vars
      
    let create_am p tuples_ =
      {
        pattern = p;
        tuples = filter p tuples_;
        vars =
          if (List.length tuples_) > 0
          then mappings p (filter p tuples_)
          else [];
      }
      
    (* helper to print BM *)
    let print_bm bm =
			match bm with 
			| InitBM -> print_string "Empty (init) BM"
			| BM bm ->
      List.iter
        (fun (var, (value, tuples)) ->
           (* (string * (t element_type * tuple list) ) *)
           (print_endline "";
            print_endline var;
            Helper.print_value value;
            print_string "[";
            List.iter (fun t -> print_string (Helper.to_string t)) tuples))
        bm.solutions
      
    (* joining BM and AM to create a new BM *)
		let gen_first_bm am= 
			 {
        solutions =
              List.fold_right
                (fun (var, values) acc ->
                   (* string * ((t element_type * tuple) list) am: (t         *)
                   (* element_type * tuple list)                              *)
                   acc @
                     (List.map
                        (fun (value, tuple) -> (var, (value, [ tuple ])))
                        values))
                am.vars []} 
    let join am bm =
          match bm with
          | InitBM -> 
            BM {   solutions = List.fold_right
                (fun (var, values) acc ->
                   (* string * ((t element_type * tuple) list) am: (t         *)
                   (* element_type * tuple list)                              *)
                   acc @
                     (List.map
                        (fun (value, tuple) -> (var, (value, [ tuple ])))
                        values))
                am.vars []} 
          | BM {solutions = solutions} ->
   					BM {solutions =
              (* (string * (t element_type * tuple list) ) list * -- existing    *)
              (* solution                                                        *)
              List.fold_right (* string * ((t element_type * tuple) list) *)
                (* am: (t element_type * tuple) list) *)
                (fun (am_var, am_values) acc ->
                   try
                     let _ = List.assoc am_var solutions in
                     (* filter all the solutions assoc with the variable *)
                     let sol_list =
                       List.filter (fun (bm_var, _) -> bm_var = am_var)
                         solutions in
                     let sol =
                       List.fold_right
                         (fun (_, (bm_value, sol_tuples)) acc_f ->
                            (* filter tuples that have matching values to  *)
                            (* corresponding variable                      *)
                            let fltr_list =
                              List.filter
                                (fun (value, _) -> value = bm_value)
                                am_values
                            in
                              acc_f @
                                (List.map
                                   (fun (_, tuple) ->
                                      (am_var,
                                       (bm_value, (tuple :: sol_tuples))))
                                   fltr_list))
                         sol_list []
                     in sol
                   with
                   | (*In a nutshell, when a variable from an AM is not found in BM solution set *)
                       (* we apply_ptrn to find values for other variable in  *)
                       (* the tuple. Eg., in case we have pattern ?x type ?y  *)
                       (* and ?x is not found in BM solutions the we check    *)
                       (* the value for ?y and see if ?y appears in the BM,   *)
                       (* if does we add the                                  *)
                       (*  tuple to the solution *) Not_found ->
                       let apply_ptrn p tuple =
                         List.fold_right
                           (fun e acc ->
                              match e with
                              | Some (var, 1) ->
                                  if var <> am_var
                                  then acc @ [ (var, ((tuple.subj), tuple)) ]
                                  else acc
                              | Some (var, 2) ->
                                  if var <> am_var
                                  then acc @ [ (var, ((tuple.pred), tuple)) ]
                                  else acc
                              | Some (var, 3) ->
                                  if var <> am_var
                                  then acc @ [ (var, ((tuple.obj), tuple)) ]
                                  else acc
                              | Some (_, _) -> acc
                              | None -> acc)
                           [ sel_arg p.subj 1; sel_arg p.pred 2;
                             sel_arg p.obj 3 ]
                           []
                       in
                         acc @
                           (List.fold_right
                              (fun (am_value, tuple) acc1 ->
                                 acc1 @
                                   (List.fold_right
                                      (fun (var, (value, tuple)) acc2 ->
                                         (* filter all the solutions assoc  *)
                                         (* with the variable               *)
                                         let sol_list =
                                           List.filter
                                             (fun
                                                (bm_var,
                                                 (bm_value, sol_tuples))
                                                ->
                                                (bm_var = var) &&
                                                  (bm_value = value))
                                             solutions
                                         in
                                           List.map
                                             (fun
                                                (bm_var,
                                                 (bm_value, sol_tuples))
                                                ->
                                                (am_var,
                                                 (am_value,
                                                  (tuple :: sol_tuples))))
                                             sol_list)
                                      (apply_ptrn am.pattern tuple) []))
                              am_values []))
                am.vars [];}

      
    (** gerenate RETE data lfow from  list of AMs **)
    let gen_rete ams =
      let first_am = List.hd ams in
     (* let empty_bm = { solutions = []; } in*)
      let tail = List.tl ams in
      let res_list =
        List.fold_right
          (fun am acc ->
             let (_, prev_bm) = List.hd acc in (am, (join am prev_bm)) :: acc)
          (List.rev tail) [ (first_am, (join first_am InitBM)) ]
      in
        List.fold_right (fun (am, bm) acc -> Node (am, bm, acc)) res_list
          Empty
      
    let compare q tpl =
      let ( = ) v1 v2 =
        match (v1, v2) with
        | (Variable _, _) -> true
        | (Constant x, Constant y) -> if x = y then true else false
        | (_, Variable _) -> false in
      let { subj = s; pred = p; obj = o; ctxt = c; time_stp = _; sign = _ } =
        q
      and
        {
          subj = q_s;
          pred = q_p;
          obj = q_o;
          ctxt = q_c;
          time_stp = _;
          sign = _
        } = tpl
      in (s = q_s) && ((p = q_p) && ((o = q_o) && (c = q_c)))
      
    (** add tuple to an existing AM **)
    (* FIX ME: implement efficient way to create new AM from the old one *)
    let add rete_network tuple =
      let get_bm node =
        match node with
        | Node (_, bm, _) -> bm
        | Empty -> InitBM in (*{ solutions = []; } in*)
      let rec regen rete_network =
        match rete_network with
        | Node (current_am, bm, node) ->
            if not (compare current_am.pattern tuple)
            then (*-let p= print_bm  bm in*)
              (let next_node = regen node
               in
                 Node (current_am, (join current_am (get_bm next_node)),
                   next_node))
            else
              (let new_am =
                 create_am current_am.pattern (tuple :: current_am.tuples)
               in
                 (* in let p3 = print_mappings new_am in let p4 = print_bm    *)
                 (* (get_bm node) in let p4 = print_string " AFTER -- " in    *)
                 (* let p5= print_bm (join new_am (get_bm node)) in let p6 =  *)
                 (* print_string " END"                                       *)
                 Node (new_am, (join new_am (get_bm node)), node))
        | Empty -> Empty
      in regen rete_network
      
    (* add list of tuples *)
    let add_tuples rete_network tuples =
      List.fold_right (fun tpl acc -> add acc tpl) tuples rete_network
      
    (*** given rete network start activations **)
    let rec execute_rete rete_network =
      let get_bm node =
        match node with
        | Node (_, bm, _) -> bm
        | Empty -> BM { solutions = []; }
      in
        match rete_network with
        | Node (am, _, node) ->
            Node (am, (join am (get_bm node)), (execute_rete node))
        | Empty -> Empty
      
    (** generate rete network from a list of query tuples *)
    let to_rete_dataflow queries tuples =
      (* let x = print_string "Initial Length: "; print_string               *)
      (* (string_of_int (List.length queries) ) in                           *)
      let am_list = List.map (fun q -> create_am q []) queries in
      (* let x = print_string "Length: "; print_string (string_of_int        *)
      (* (List.length am_list) ) in                                          *)
      let rn =
        match am_list with
        | [] -> (print_string "for some reason the AM list is empty"; Empty)
        | l -> gen_rete l in
      let new_rn = match tuples with | [] -> rn | tpls -> add_tuples rn tpls
      in
        (* let p=Helper.print_tuples (Helper.flatten_tuple_list                *)
        (* (get_sol_tuples new_rn)) in let Node (_, bm, _) = new_rn in         *)
        (* print_bm bm;                                                        *)
        new_rn
      
    (** function to create rete newtork from a query **)
    let to_rete str tuples =
      let qs = Helper.str_query_list str in
      let ams = List.map (fun q -> create_am q tuples) qs in gen_rete ams
      
    (** function to return a list of values for a particular variable in the solution (BM) **)
    let get_lst_value bm var =
      List.fold_right
        (fun (v, (value, _)) acc2 ->
           (* (string * (t element_type * tuple list) ) *)
           if var = v then value :: acc2 else acc2)
        bm.solutions []
      
    (** deprecated: function to return a list of values for a particular variable in the solution (BM) **)
    let get_lst_values bm (vars : string list) = (* helper to print BM *)
      List.fold_right
        (fun var acc ->
           let sols =
             List.fold_right
               (fun (v, (value, _)) acc2 ->
                  (* (string * (t element_type * tuple list) ) *)
                  if var = v then value :: acc2 else List.rev acc2)
               bm.solutions []
           in if (List.length sols) <> 0 then [ (var, sols) ] @ acc else acc)
        vars []
      
    (** function to return a Map of values for a particular variable in the solution (BM) **)
    let get_values_map bm (vars : string list) = (* helper to print BM *)
      List.fold_right
        (fun var acc ->
           let sols =
             List.fold_right
               (fun (v, (value, _)) acc2 ->
                  (* (string * (t element_type * tuple list) ) *)
                  if var = v then value :: acc2 else List.rev acc2)
               bm.solutions []
           in
             if (List.length sols) <> 0
             then Helper.StringMap.add var sols acc
             else acc)
        vars Helper.StringMap.empty
      
    (** given rete network get the current values associated with var **)
    let rec get_values rete_network (vars : string list) =
      (* check whether the variable has been found, return vars that still   *)
      (* missing *                                                           *)
      let missing_vars values_map =
        List.filter (fun v -> not (Helper.StringMap.mem v values_map)) vars
      in
        match rete_network with
        | Node (_, BM bm, node) ->
            let values_map = get_values_map bm vars in
            let mvars = missing_vars values_map
            in
              (Helper.StringMap.bindings values_map) @
                (get_values node mvars)
        | Empty -> []
      
    (** generates a MAP with Var, Values pairs from the results **)
    let get_res_map rete_network vars =
      let res_map = Helper.StringMap.empty in
      let result = get_values rete_network vars
      in
        List.fold_right
          (fun (var, values) acc -> Helper.StringMap.add var values acc)
          result res_map
      
    (** helper method accepts query string and runs it over tuples,
	extracts the values associated with the var **)
    let exec_qry q tuples =
      let network = to_rete q tuples in execute_rete network
      
    let get_tuples network =
      let tuples_set = Helper.TupleSet.empty
      in
        match network with
       (* | Node (_, { solutions = sols }, _) ->*)
			 | Node (_, BM { solutions = sols }, _) ->
            List.fold_right
              (fun (_, var_sols) acc ->
                 let (_, tuples) = var_sols
                 in List.fold_right Helper.TupleSet.add tuples acc)
              sols tuples_set
        | Empty -> tuples_set
      
    (** helper method accepts query string and runs it over tuples in a given BM,
	extracts the values associated with the var **)
    let exec_bm q network =
      let network = to_rete q (Helper.TupleSet.elements (get_tuples network))
      in execute_rete network
      
    (* takes a list of AMs and joins them *)
    let execute_am_list ams =
      let empty_bm = { solutions = []; }
      in List.fold_right (fun am acc -> join am acc) ams InitBM
      
    (* returns solution tuples in a list *)
    let get_sol_tuples network =
      match network with
      | Node (_, BM { solutions = sols }, _) ->
          List.fold_right
            (fun (_, var_sols) acc ->
               let (_, tuples) = var_sols
               in tuples :: (*Helper.print_tuples tuples; *) acc)
            sols []
      | Empty -> []
      | BNode tuples -> [ tuples ]
      
  end
  
	

