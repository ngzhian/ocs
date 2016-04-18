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
    post_paths : string list;
    posts : post list;
    template: string;
  }

type config =
  { dir: string;
  }

val md_to_post : string -> post
val search_for_mds : string -> string list

val generate : config -> unit
val generate_default : unit -> unit

val apply_template : string -> post -> post

val get_title : Omd.t -> string

val build_site : config -> site
val convert : site -> site
val write : site -> unit
