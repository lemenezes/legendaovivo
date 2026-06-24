const docs = require('express').Router();
const helpscout = require('./helpscout');

const hasHelpscoutConfig =
  Boolean(process.env.HELPSCOUT_DOCS_API_KEY) &&
  Boolean(process.env.HELPSCOUT_DOCS_COLLECTION_ID);

const safeAsync = (handler) => async (req, res, next) => {
  try {
    await handler(req, res, next);
  } catch (error) {
    console.error('Docs API error:', error);
    if (!res.headersSent) {
      res.sendStatus(503);
    }
  }
};

let viewCounts = {};

const logViewCount = (articleId) => {
  if (!viewCounts[articleId]) {
    viewCounts[articleId] = 0;
  }

  viewCounts[articleId]++;

  // For bandwidth, wait until view count reaches a certain
  // point before logging hits with the Helpscout service.
  if (viewCounts[articleId] >= 10) {
    // Log the hits
    helpscout.updateViewCount({ articleId, count: viewCounts[articleId] });
    viewCounts[articleId] = 0;
  }
};

docs.get('/categories/:categorySlug', safeAsync(async (req, res) => {
  let { categorySlug } = req.params;

  if (!categorySlug) {
    return res.sendStatus(422);
  }

  if (!hasHelpscoutConfig) {
    return res.sendStatus(404);
  }

  let category = await helpscout.category({ categorySlug });
  res.cacheControl = {
    maxAge: 60 * 5,
  };
  return category ? res.send(category) : res.sendStatus(404);
}));

docs.get('/categories/:categorySlug/articles', safeAsync(async (req, res) => {
  let { categorySlug } = req.params;

  if (!categorySlug) {
    return res.sendStatus(422);
  }

  if (!hasHelpscoutConfig) {
    return res.send([]);
  }

  let articles = await helpscout.articlesForCategory({ categorySlug });

  res.cacheControl = {
    maxAge: 60 * 5,
  };
  res.send(articles || []);
}));

docs.get(
  '/categories/:categorySlug/articles/:articleSlug',
  safeAsync(async (req, res) => {
    let { categorySlug, articleSlug } = req.params;

    if (!categorySlug && !articleSlug) {
      return res.sendStatus(422);
    }

    if (!hasHelpscoutConfig) {
      return res.sendStatus(404);
    }

    try {
      let article = await helpscout.article({ categorySlug, articleSlug });
      if (!article) {
        throw new Error('Article not found');
      }

      res.cacheControl = {
        maxAge: 60 * 5,
      };
      res.send(article);
      logViewCount(article.articleId);
    } catch (e) {
      return res.sendStatus(404);
    }
  })
);

docs.get('/articles', safeAsync(async (req, res) => {
  let { query } = req.query;

  if (!query) {
    return res.sendStatus(422);
  }

  if (!hasHelpscoutConfig) {
    return res.send([]);
  }

  let articles = await helpscout.search({ query });
  res.cacheControl = {
    maxAge: 60 * 5,
  };
  res.send(articles || []);
}));

module.exports = docs;
