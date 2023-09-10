class Image {
  final Uri url;
  final int width;
  final int height;

  Image.fromJson(Map<String, dynamic> data)
      : url = Uri.parse(data["url"]).replace(scheme: "https"),
        width = data["width"],
        height = data["height"];
}
