import {
  DISCORD_INVITE,
  SITE_AUTHOR,
  SOCIAL_GITHUB,
  SOCIAL_TWITTER,
} from "../../../../constants";

export const Footer = () => {
  return (
    <footer id="footer">
      <hr className="w-11/12 mx-auto" />

      <section className="container py-20 grid grid-cols-2 md:grid-cols-4 xl:grid-cols-6 gap-x-12 gap-y-8">
        <div className="col-span-full xl:col-span-2">
          <a
            rel="noreferrer noopener"
            href="/"
            className="font-bold text-xl flex"
          >
            Airstreams
          </a>
        </div>

        <div className="flex flex-col gap-2">
          <h3 className="font-bold text-lg">Follow Us</h3>
          <div>
            <a
              rel="noreferrer noopener"
              href={`https://github.com/${SOCIAL_GITHUB}`}
              className="opacity-60 hover:opacity-100"
            >
              Github
            </a>
          </div>

          <div>
            <a
              rel="noreferrer noopener"
              href={`https://x.com/${SOCIAL_TWITTER}`}
              className="opacity-60 hover:opacity-100"
            >
              X
            </a>
          </div>
        </div>

        <div className="flex flex-col gap-2">
          <h3 className="font-bold text-lg">Blossom Labs</h3>
          <div>
            <a
              rel="noreferrer noopener"
              href="https://blossom.software"
              className="opacity-60 hover:opacity-100"
            >
              Website
            </a>
          </div>
        </div>

        <div className="flex flex-col gap-2">
          <h3 className="font-bold text-lg">Other tools</h3>
          <div>
            <a
              rel="noreferrer noopener"
              href="https://evmcrispr.com"
              className="opacity-60 hover:opacity-100"
            >
              EVMcrispr
            </a>
          </div>

          <div>
            <a
              rel="noreferrer noopener"
              href="https://governor.haus"
              className="opacity-60 hover:opacity-100"
            >
              Governor.Haus
            </a>
          </div>

          <div>
            <a
              rel="noreferrer noopener"
              href="https://council.haus"
              className="opacity-60 hover:opacity-100"
            >
              Council.Haus
            </a>
          </div>
        </div>

        <div className="flex flex-col gap-2">
          <h3 className="font-bold text-lg">Community</h3>
          <div>
            <a
              rel="noreferrer noopener"
              href={`https://discordapp.com/invite/${DISCORD_INVITE}`}
              className="opacity-60 hover:opacity-100"
            >
              Discord
            </a>
          </div>
        </div>
      </section>

      <section className="container pb-14 text-center">
        <h3>
          &copy; 2024{" "}
          <a
            rel="noreferrer noopener"
            target="_blank"
            href={`https://github.com/${SOCIAL_GITHUB}`}
            className="text-primary transition-all border-primary hover:border-b-2"
          >
            {SITE_AUTHOR}
          </a>
        </h3>
      </section>
    </footer>
  );
};
