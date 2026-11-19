// Winzige echte WebP-Bilder für Tests (je rund 250 Bytes): ein Foto im
// Format 80 x 48 und ein Logo im Format 48 x 48.

import 'dart:convert';
import 'dart:typed_data';

final photoWebp = Uint8List.fromList(
  base64Decode(
    'UklGRgoBAABXRUJQVlA4IP4AAADQBwCdASpQADAAPw1urlAsJiQiszjqqYAhiWgAssnsW8BB0cfEymsUpe1jJ3kDxW/MveCxz0RAEI+tRr37hE8NkL4JVShEAAD+h9aFdZe+mx7bepOw2e1Jyiu5c41qldeWcit6IPjcnAEeqM/zakfnk1mslzYj4BC3eZLfJRceIh5JMP4i2LUYKRgA8ogwitVDg2r+tX0JDjKNHBgeKtJbBm3oHUtN2/GrmxhDOKl5nLlhgMjc+Si122H7BUEUmCAmQnbFgCAvESkonMM76TkqttdrrXAAyFHuDkfIWu+F3Y6JpSgvmwS7Bfq0YBV4/XNqoqQ4Vl5zVY0KeLoAAA==',
  ),
);

final logoWebp = Uint8List.fromList(
  base64Decode(
    'UklGRvIAAABXRUJQVlA4IOYAAADQBgCdASowADAAPvlsp1AqpqOiuNbcAVAfCWgAwQvWSLjANwAjv6znJHfYJ135PiAtHFYvGhQFeD4w/FgRVgAA/Mr/rbtH1tcv/+Wf/n9/F3o8V4nAz2LDHKC9J/EAGS7JFIIT+LZVleCMLsg6sHDtxmSkpQ21JV1wFf+SLxWt8qbn9LiRtAdtbQrvaU9qcb9V9gWp5S6KKjXRuJMUKotMvihqreNif8OO5+ptoZ6mkGOwwq1IKjLcJaroJPEao3j+xUjGJBevXzwdKk1OBs4HynQsVgt6SQTDA3iAW3QKrAygsjXgAA==',
  ),
);
