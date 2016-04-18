open Core.Std

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

let get_title md = 
  match md with
  | (Omd.H1 h1) :: _ -> (
    match h1 with
    | (Omd.Text t) :: _ -> t
    | _ -> ""
  )
  | _ -> ""

let is_md path =
  String.is_suffix path ~suffix:".md"

let search_for_mds dir =
  Sys.ls_dir dir
  |> List.filter ~f:is_md

let md_to_post path =
  let contents = In_channel.read_all path in
  let md = Omd.of_string contents in
  let title = get_title md in
  let html = Omd.to_html (Omd.of_string contents) in
  let html_path = String.chop_suffix_exn path ~suffix:".md" ^ ".html" in
  { path; contents; html; title; html_path; }

let jg_template template post =
  let open Jg_types in
  let pt = Tobj [("content", Tstr post.html); ("title", Tstr post.title)] in
  Jg_template.from_string template ~models:[("post", pt)]

let apply_template template post =
  { post with html =
      jg_template template post
  }

let write site =
  let write_html post = Out_channel.write_all post.html_path ~data:post.html in
  List.iter site.posts ~f:write_html
  
let build_site config =
  let template_path = Filename.concat config.dir "post.html" in
  let template = In_channel.read_all template_path in
  let post_paths = search_for_mds config.dir in
  { base_dir = config.dir; post_paths; template; posts = []}

let convert site =
  let posts = 
    site.post_paths
    |> List.map ~f:md_to_post
    |> List.map ~f:(apply_template site.template) in
  {site with posts}
  
let generate config =
  build_site config
  |> convert
  |> write

let default_config = 
  { dir = "."
  }

let generate_default () =
  generate default_config

let generate_with_dir dir =
  generate { dir }

(**
 *  Command line interface to ocs.
 *)
let () =
  Command.run ~version:"1.0" (
    Command.basic 
    ~summary:"Generate a static blog from markdown"
    Command.Spec.(
      empty
      +> flag "-d" (optional string) ~doc:"directory"
    )
    (fun dir () -> match dir with
       | Some path -> generate_with_dir path
       | None -> generate_default () ))
