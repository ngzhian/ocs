(** A static blog generator. *)

type post =
  { path : string;
    contents: string;
    html: string;
    title: string;
    html_path: string;
  }

type site =
  { base_dir: string;
    posts : post list;
    template: string;
  }

val md_to_post : string -> post
val list_dir : string -> string list

(* (md file path * html) *)
val all_html : string -> string -> post list
val write : site -> unit

val generate : string -> unit

val apply_template : string -> post -> post

(* val tt : Omd_representation.element -> string *)
val get_title : Omd.t -> string

val build_site : string -> site
