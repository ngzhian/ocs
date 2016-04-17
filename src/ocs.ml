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
    posts : post list;
    template: string;
  }

let get_title md = 
  match md with
  | (Omd.H1 h1) :: _ -> (
    match h1 with
    | (Omd.Text t) :: _ -> t
    | _ -> ""
  )
  | _ -> ""

let md_to_post path =
  let contents = In_channel.read_all path in
  let md = Omd.of_string contents in
  let title = get_title md in
  let html = Omd.to_html (Omd.of_string contents) in
  let html_path = String.chop_suffix_exn path ~suffix:".md" ^ ".html" in
  { path; contents; html; title; html_path; }

let list_dir dir =
  let is_md path = String.is_suffix path ~suffix:".md" in
  Sys.ls_dir dir
  |> List.filter ~f:is_md

let apply_template template post =
  { post with html = 
      Str.replace_first (Str.regexp "{{BODY}}") post.html template
      |> Str.replace_first (Str.regexp "{{TITLE}}") post.title }

let all_html dir template = 
  list_dir dir
  |> List.map ~f:md_to_post
  |> List.map ~f:(apply_template template)

let write site =
  let write_html post = Out_channel.write_all post.html_path ~data:post.html in
  List.iter site.posts ~f:write_html
  
let build_site dir =
  let template_path = Filename.concat dir "post.html" in
  let template = In_channel.read_all template_path in
  let posts = all_html dir template in
  { base_dir = dir; posts; template; }
  
let generate dir =
  build_site dir
  |> write
